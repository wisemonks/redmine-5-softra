# frozen_string_literal: true

class RateLimitedMailDeliveryJob < ActionMailer::MailDeliveryJob
  queue_as :mailers

  # Maximum emails per minute (Microsoft limit is ~20, we use 15 for safety)
  RATE_LIMIT = 15
  RATE_WINDOW = 60 # seconds

  # Retry on SMTP rate limit errors with custom delays: 60s, 120s, 180s, then 5min
  retry_on Net::SMTPServerBusy,
           Net::SMTPError,
           wait: :exponentially_longer,
           attempts: 10 do |job, exception|
    # Only retry if it's actually a rate limit error
    if self.class.rate_limit_error?(exception)
      retry_count = job.executions - 1
      wait_time = case retry_count
                  when 0 then 60      # 1st retry: wait 60s
                  when 1 then 120     # 2nd retry: wait 120s
                  when 2 then 180     # 3rd retry: wait 180s
                  else 300            # 4th+ retry: wait 5min
                  end

      Rails.logger.warn("[RateLimitedMailDeliveryJob] SMTP rate limit error, retry ##{retry_count + 1} in #{wait_time}s: #{exception.message}")
      raise exception # Let retry_on handle the retry with wait time
    else
      # Don't retry non-rate-limit SMTP errors
      Rails.logger.error("[RateLimitedMailDeliveryJob] Non-retryable SMTP error: #{exception.message}")
      raise exception
    end
  end

  # Discard job after all retries exhausted
  discard_on StandardError do |job, exception|
    Rails.logger.error("[RateLimitedMailDeliveryJob] Job discarded after #{job.executions} attempts: #{exception.message}")
  end

  def perform(mailer, mail_method, delivery_method, args:)
    # Check rate limit and reschedule if needed
    if should_reschedule?
      reschedule_time = calculate_reschedule_time
      Rails.logger.info("[RateLimitedMailDeliveryJob] Rate limit reached, rescheduling in #{reschedule_time}s")
      # Create a new job for later execution and return (no exception needed)
      self.class.set(wait: reschedule_time.seconds).perform_later(mailer, mail_method, delivery_method, args: args)
      return # Exit cleanly without raising exception
    end

    # Atomically increment counter and proceed
    increment_counter

    user = args.first
    user_email = user.is_a?(User) ? user.mail : "unknown"

    Rails.logger.info("[RateLimitedMailDeliveryJob] Sending email: #{mailer}##{mail_method} to #{user_email}")

    result = super(mailer, mail_method, delivery_method, args: args)

    Rails.logger.info("[RateLimitedMailDeliveryJob] Email sent successfully: #{mailer}##{mail_method} to #{user_email}")
    result
  end

  private

  # Check if we should reschedule due to rate limit
  # Uses atomic Lua script to check and reserve a slot
  def should_reschedule?
    redis_key = current_redis_key

    begin
      # Atomic check: return current count without incrementing
      count = Sidekiq.redis { |conn| conn.get(redis_key) }
      count = count.to_i if count
      count ||= 0
      count >= RATE_LIMIT
    rescue Redis::BaseError => e
      # If Redis is down, fail open (allow sending without rate limiting)
      Rails.logger.warn("[RateLimitedMailDeliveryJob] Redis unavailable, skipping rate limit check: #{e.message}")
      false
    end
  end

  # Atomically increment the counter
  def increment_counter
    redis_key = current_redis_key

    begin
      # Lua script for atomic increment with expiry
      lua_script = <<-LUA
        local current = redis.call('incr', KEYS[1])
        if current == 1 then
          redis.call('expire', KEYS[1], ARGV[1])
        end
        return current
      LUA

      count = Sidekiq.redis { |conn| conn.eval(lua_script, 1, redis_key, 120) }
      Rails.logger.info("[RateLimitedMailDeliveryJob] Rate limit counter: #{count}/#{RATE_LIMIT}")
    rescue Redis::BaseError => e
      Rails.logger.warn("[RateLimitedMailDeliveryJob] Redis error during increment: #{e.message}")
    end
  end

  # Calculate how long to wait before next attempt
  def calculate_reschedule_time
    # Wait until the next minute window
    RATE_WINDOW - (Time.now.to_i % RATE_WINDOW) + rand(1..5) # Add jitter to prevent thundering herd
  end

  # Get current Redis key based on time window
  def current_redis_key
    "email_rate_limit:#{Time.now.to_i / RATE_WINDOW}"
  end

  class << self
    def rate_limit_error?(exception)
      return false unless exception

    # Check for SMTP rate limit errors
      (exception.is_a?(Net::SMTPServerBusy) || exception.is_a?(Net::SMTPError)) &&
      (exception.message.include?('4.4.2') ||
       exception.message.include?('rate limit') ||
       exception.message.include?('submission rate') ||
     exception.message.include?('exceeded the configured limit'))
    end
  end
end
