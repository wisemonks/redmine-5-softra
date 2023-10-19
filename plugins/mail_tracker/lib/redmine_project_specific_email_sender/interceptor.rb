module RedmineProjectSpecificEmailSender
  class Interceptor
    def self.delivering_email(message)
      if sender = message.header['X-Redmine-Project-Specific-Sender']
        message.from = [sender.to_s]
        message.header['X-Redmine-Project-Specific-Sender'] = nil
      end

      if project_identifier = message.header['X-Redmine-Project']
        project_email = Project.find_by(identifier: project_identifier.to_s).try(:email)
        project_email = Mail::Address.new(project_email).address
        mail_source = MailSource.find_by(email_address: project_email)

        message.delivery_method(:smtp, mail_source.delivery_options) if mail_source
      end

      MailTrackerCustomLogger.logger.info("Interceptor: Using SMTP #{message.delivery_method.settings[:address]}, PORT: #{message.delivery_method.settings[:port]}, DOMAIN:#{message.delivery_method.settings[:domain]}, USERNAME: #{message.delivery_method.settings[:user_name]}")
      MailTrackerCustomLogger.logger.info("Interceptor: Delivering from #{message.from} to #{message.to}: #{message.subject}")
    end
  end
end

# message.delivery_method(:smtp, {
#   enable_starttls_auto:  mail_source.use_tls,
#   address:              mail_source.host,
#   port:                 mail_source.delivery_port || 587,
#   domain:               mail_source.domain,
#   authentication:       :login,
#   user_name:            mail_source.username,
#   password:             mail_source.password,
#   openssl_verify_mode:  'none',
# }) if mail_source