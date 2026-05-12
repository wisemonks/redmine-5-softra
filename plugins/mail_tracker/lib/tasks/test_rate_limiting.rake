namespace :mail_tracker do
  desc 'Test rate limiting with multiple emails to verify all are delivered'
  task :test_rate_limiting => :environment do
    puts "\n=== Testing Rate Limited Email Delivery ==="
    puts "This will create 20 journal entries with 2 watchers (40 total emails)"
    puts "Rate limit: 15 emails/minute"
    puts "Expected behavior:"
    puts "  - First 15 emails: sent immediately"
    puts "  - Email 16+: delayed until next minute window"
    puts "  - All 40 emails should eventually be delivered"
    puts "\nStarting test...\n\n"

    # Clean up Redis counter
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      redis.keys('email_rate_limit:*').each { |key| redis.del(key) }
      puts "✓ Cleared Redis rate limit counters"
    rescue => e
      puts "⚠ Redis not available: #{e.message}"
    end

    # Find or use specified user
    email = ENV['EMAIL'] || 'arturas@wisemonks.com'
    user = User.active.joins(:email_addresses).where(email_addresses: { address: email }).first

    unless user
      puts "✗ User with email #{email} not found!"
      puts "Usage: EMAIL=user@example.com bundle exec rake mail_tracker:test_rate_limiting"
      exit 1
    end

    puts "✓ Sending emails to: #{user.login} (#{email})"
    puts "✓ Watch Sidekiq logs for rate limiting messages"
    puts "✓ Check tmp/letter_opener/ for email files\n\n"

    # Create a test issue and journal in the test project
    project = Project.find_by(identifier: 'testavimas')
    unless project
      puts "✗ Test project 'testavimas' not found!"
      puts "Available projects:"
      Project.limit(5).each { |p| puts "  - #{p.identifier} (#{p.name})" }
      exit 1
    end

    puts "✓ Using project: #{project.name} (#{project.identifier})"

    issue = Issue.new(
      project: project,
      tracker: project.trackers.first,
      author: user,
      subject: "Rate Limit Test - #{Time.now}",
      description: "Testing rate limiting with 20 emails"
    )
    issue.save!

    # Add the test user as a watcher to ensure they receive emails
    unless issue.watched_by?(user)
      Watcher.create!(watchable: issue, user: user)
      puts "✓ Added watcher: #{user.login} (#{email})"
    end

    # Optionally add a second watcher for testing multiple recipients
    watcher = User.active.joins(:email_addresses).where(email_addresses: { address: 'rytis@wisemonks.com' }).first
    if watcher && !issue.watched_by?(watcher)
      Watcher.create!(watchable: issue, user: watcher)
      puts "✓ Added second watcher: #{watcher.login} (rytis@wisemonks.com)"
    end

    # Create 20 journal entries - Redmine will automatically send emails to watchers
    20.times do |i|
      Journal.create!(
        journalized: issue,
        user: user,
        notes: "Test email #{i + 1}/20"
      )
      print "."
    end

    puts "\n\n✓ Created 20 journal entries (emails will be sent automatically to #{issue.watcher_users.count} watchers)"
    puts "\nMonitoring Redis counter and Sidekiq logs..."
    puts "Press Ctrl+C to stop monitoring\n\n"

    # Monitor Redis counter
    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))

      start_time = Time.now
      last_count = 0

      loop do
        sleep 2
        elapsed = (Time.now - start_time).to_i

        redis_key = "email_rate_limit:#{Time.now.to_i / 60}"
        count = redis.get(redis_key).to_i

        if count != last_count
          puts "[#{elapsed}s] Redis counter: #{count}/15"
          last_count = count
        end

        # Check Sidekiq queue
        require 'sidekiq/api'
        stats = Sidekiq::Stats.new
        if stats.enqueued > 0
          puts "[#{elapsed}s] Sidekiq queue: #{stats.enqueued} jobs pending"
        end

        # Stop after 2 minutes
        break if elapsed > 120
      end

      puts "\n=== Test Complete ==="
      puts "Check tmp/letter_opener/ for all 20 email files"
      puts "Run: ls -lt tmp/letter_opener/ | head -25"

    rescue Redis::CannotConnectError
      puts "⚠ Redis not available - cannot monitor counter"
    rescue Interrupt
      puts "\n\nMonitoring stopped by user"
    end
  end

  desc 'Count emails in letter_opener directory'
  task :count_emails => :environment do
    dir = Rails.root.join('tmp', 'letter_opener')
    if Dir.exist?(dir)
      count = Dir.entries(dir).count { |e| !e.start_with?('.') }
      puts "Total email folders in tmp/letter_opener/: #{count}"

      # Show last 10
      puts "\nLast 10 emails:"
      `ls -lt #{dir} | head -11`.split("\n")[1..-1].each do |line|
        puts "  #{line}"
      end
    else
      puts "No letter_opener directory found"
    end
  end

  desc 'Clear all test emails from letter_opener'
  task :clear_emails => :environment do
    dir = Rails.root.join('tmp', 'letter_opener')
    if Dir.exist?(dir)
      count = Dir.entries(dir).count { |e| !e.start_with?('.') }
      FileUtils.rm_rf(Dir.glob("#{dir}/*"))
      puts "✓ Cleared #{count} email folders from tmp/letter_opener/"
    else
      puts "No letter_opener directory found"
    end
  end

  desc 'Check email delivery and rate limiting configuration'
  task check_config: :environment do
    puts "\n=== Email Delivery Configuration ==="
    puts "  Delivery method: #{ActionMailer::Base.delivery_method}"
    puts "  Delivery job: #{ActionMailer::Base.delivery_job}"
    puts "  Queue adapter: #{Rails.application.config.active_job.queue_adapter}"
    puts "  Perform deliveries: #{ActionMailer::Base.perform_deliveries}"

    if defined?(Sidekiq)
      puts "\n=== Sidekiq Configuration ==="
      puts "  Redis URL: #{Sidekiq.redis { |conn| conn.connection[:host] rescue 'N/A' }}"
      puts "  Queues: #{Sidekiq.options[:queues].inspect rescue 'N/A'}"
    else
      puts "\n⚠ Sidekiq: NOT LOADED"
    end

    begin
      redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
      if redis.ping == 'PONG'
        puts "\n✓ Redis: CONNECTED"

        # Show current rate limit counter
        redis_key = "email_rate_limit:#{Time.now.to_i / 60}"
        count = redis.get(redis_key).to_i
        puts "  Current rate limit counter: #{count}/15"
      end
    rescue Redis::CannotConnectError
      puts "\n⚠ Redis: NOT CONNECTED (rate limiting will fail open)"
    end

    puts "\n=== Rate Limiting Settings ==="
    puts "  Rate limit: #{RateLimitedMailDeliveryJob::RATE_LIMIT} emails/minute"
    puts "  Rate window: #{RateLimitedMailDeliveryJob::RATE_WINDOW} seconds"
    puts "\n"
  end
end
