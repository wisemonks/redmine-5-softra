class EmailQueue < ActiveRecord::Base
  MAX_RETRY_COUNT = 5

  RETRY_DELAYS = {
    0 => 0,
    1 => 1.minute,
    2 => 2.minutes,
    3 => 3.minutes,
    4 => 5.minutes,
    5 => 10.minutes
  }.freeze

  scope :pending, -> { where(delivered_at: nil) }
  scope :delivered, -> { where.not(delivered_at: nil) }
  scope :failed, -> { where.not(failed_at: nil) }
  scope :oldest_first, -> { order(created_at: :asc) }

  def self.enqueue(mailer_class, mailer_method, delivery_method, args, mail = nil)
    recipient_email = extract_recipient_email(args)
    subject = mail&.subject

    create!(
      mailer_class: mailer_class,
      mailer_method: mailer_method,
      delivery_method: delivery_method,
      serialized_args: serialize_args(args),
      serialized_mail: mail ? serialize_mail(mail) : nil,
      recipient_email: recipient_email,
      subject: subject,
      retry_count: 0
    )
  end

  def self.process_batch(limit = 15)
    emails = ready_to_send(limit)
    Rails.logger.info("[EmailQueue] Processing #{emails.size} emails from queue (by retry priority)")

    emails.each do |email|
      email.process
    end

    emails.size
  end

  def self.ready_to_send(limit = 15)
    batch = []

    # Build batch by priority: 0 retries, then 1, then 2, etc.
    (0..MAX_RETRY_COUNT).each do |retry_count|
      break if batch.size >= limit
      add_emails_to_batch(batch, retry_count, limit)
    end

    batch
  end

  def self.add_emails_to_batch(batch, retry_count, limit)
    return if batch.size >= limit

    delay = RETRY_DELAYS[retry_count] || RETRY_DELAYS[MAX_RETRY_COUNT]

    query = pending.where(retry_count: retry_count).oldest_first

    # For retry_count > 0, check if enough time has passed
    if retry_count > 0
      query = query.where("last_attempted_at <= ?", Time.current - delay)
    end

    emails = query.limit(limit - batch.size).to_a

    if emails.any?
      batch.concat(emails)
      retry_label = retry_count == 0 ? "new emails" : "emails with #{retry_count} #{retry_count == 1 ? 'retry' : 'retries'}"
      Rails.logger.info("[EmailQueue] Added #{emails.size} #{retry_label}")
    end
  end

  def process
    return if delivered_at.present?

    update!(last_attempted_at: Time.current)

    begin
      Rails.logger.info("[EmailQueue] Processing email ##{id} to #{recipient_email} (attempt #{retry_count + 1})")

      args = deserialize_args(serialized_args)
      mailer = mailer_class.constantize
      mail = mailer.send(mailer_method, *args)

      # Restore attachments if they were serialized
      if serialized_mail.present?
        mail_data = JSON.parse(serialized_mail)
        if mail_data['attachments'] && mail_data['attachments'].any?
          Rails.logger.info("[EmailQueue] Restoring #{mail_data['attachments'].size} attachments")
          mail_data['attachments'].each do |attachment_data|
            # Use strict decode for binary attachments
            decoded_content = Base64.strict_decode64(attachment_data['body'])

            mail.attachments[attachment_data['filename']] = {
              mime_type: attachment_data['content_type'],
              content: decoded_content
            }
          end
        end
      end

      # Use mail source configuration
      mail_source = find_mail_source(args)
      if mail_source
        mail_source.token_refresher if mail_source.oauth_enabled && mail_source.refresh_token
        mail.delivery_method :smtp, mail_source.delivery_options
        MailTrackerCustomLogger.logger.info("Sending email from #{mail.from} to #{mail.to}: #{mail.subject}")
      end

      mail.deliver_now

      mark_as_delivered!
      Rails.logger.info("[EmailQueue] Email ##{id} delivered successfully")
    rescue StandardError => e
      handle_error(e)
    end
  end

  def mark_as_delivered!
    update!(delivered_at: Time.current)
  end

  def mark_as_failed!
    update!(failed_at: Time.current)
  end

  def increment_retry!
    increment!(:retry_count)
  end

  private

  def handle_error(exception)
    increment_retry!

    error_message = "#{exception.class}: #{exception.message}"
    Rails.logger.error("[EmailQueue] Email ##{id} failed (attempt #{retry_count}): #{error_message}")

    if retry_count > MAX_RETRY_COUNT
      mark_as_failed!
      report_to_sentry(exception)
      Rails.logger.error("[EmailQueue] Email ##{id} permanently failed after #{retry_count} attempts")
    else
      next_retry = last_attempted_at + (RETRY_DELAYS[retry_count] || RETRY_DELAYS[5])
      Rails.logger.info("[EmailQueue] Email ##{id} will be retried at #{next_retry} (#{retry_count}/#{MAX_RETRY_COUNT})")
    end
  end

  def report_to_sentry(exception)
    return unless defined?(Sentry)

    Sentry.capture_exception(exception, extra: {
      email_queue_id: id,
      recipient_email: recipient_email,
      subject: subject,
      mailer_class: mailer_class,
      mailer_method: mailer_method,
      retry_count: retry_count,
      last_attempted_at: last_attempted_at
    })
  rescue StandardError => e
    Rails.logger.error("[EmailQueue] Failed to report to Sentry: #{e.message}")
  end

  def find_mail_source(args)
    user = args.first
    return nil unless user.is_a?(User)

    project = args[1] if args[1].is_a?(Project)
    return nil unless project

    MailSource.find_by(project_id: project.id)
  end

  def self.extract_recipient_email(args)
    user = args.first
    user.is_a?(User) ? user.mail : nil
  end

  def self.serialize_args(args)
    args.map do |arg|
      if arg.is_a?(ActiveRecord::Base)
        { class: arg.class.name, id: arg.id }
      else
        arg
      end
    end.to_json
  end

  def deserialize_args(serialized)
    JSON.parse(serialized).map do |arg|
      if arg.is_a?(Hash) && arg['class'] && arg['id']
        begin
          klass = arg['class'].constantize
          object = klass.find(arg['id'])
          Rails.logger.debug("[EmailQueue] Deserialized #{klass.name} ID #{arg['id']}")
          object
        rescue => e
          Rails.logger.error("[EmailQueue] Failed to deserialize #{arg['class']} ID #{arg['id']}: #{e.message}")
          arg
        end
      else
        arg
      end
    end
  end

  def self.serialize_mail(mail)
    serialized = {
      from: mail.from,
      to: mail.to,
      subject: mail.subject,
      body: mail.body.to_s
    }

    # Serialize attachments if present
    if mail.respond_to?(:attachments) && mail.attachments.any?
      serialized[:attachments] = mail.attachments.map do |attachment|
        # Handle binary attachments properly
        attachment_body = attachment.body.raw_source rescue attachment.body.to_s

        {
          filename: attachment.filename,
          content_type: attachment.content_type,
          body: Base64.strict_encode64(attachment_body)
        }
      end
    end

    serialized.to_json
  rescue StandardError => e
    Rails.logger.warn("[EmailQueue] Failed to serialize mail: #{e.message}")
    nil
  end
end
