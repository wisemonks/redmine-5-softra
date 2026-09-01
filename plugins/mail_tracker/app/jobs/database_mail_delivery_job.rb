class DatabaseMailDeliveryJob < ActionMailer::MailDeliveryJob
  def perform(mailer, mail_method, delivery_method, args:)
    Rails.logger.info("[DatabaseMailDeliveryJob] Queueing email: #{mailer}##{mail_method}")

    begin
      mail = mailer.constantize.send(mail_method, *args)
      EmailQueue.enqueue(mailer, mail_method, delivery_method, args, mail)
      Rails.logger.info("[DatabaseMailDeliveryJob] Email queued successfully")
    rescue StandardError => e
      Rails.logger.error("[DatabaseMailDeliveryJob] Failed to queue email: #{e.message}")
      raise
    end
  end
end
