require_relative '../test_helper'

class MailSourcesTest < ActiveSupport::TestCase
  def test_deliver_uses_deliver_later
    # This test verifies that MailSource#deliver uses mail.deliver_later
    # which will trigger RateLimitedMailDeliveryJob

    skip 'MailSource requires database setup' unless MailSource.table_exists?

    # Create a test mail object
    test_mail = Mail.new do
      from     'test@example.com'
      to       'recipient@example.com'
      subject  'Test Email'
      body     'Test body'
    end

    # Create a mock MailSource with minimal required fields
    mail_source = MailSource.new(
      email_address: 'test@example.com',
      host: 'smtp.example.com',
      delivery_port: 587,
      oauth_enabled: false,
      username: 'test',
      password: 'test'
    )

    # Verify that deliver_later is called on the mail object
    # This ensures our RateLimitedMailDeliveryJob will be used
    test_mail.expects(:delivery_method).with(:smtp, anything)
    test_mail.expects(:deliver_later).once

    mail_source.deliver(test_mail)
  end

  def test_rate_limited_job_is_configured
    # Verify that ActionMailer is configured to use RateLimitedMailDeliveryJob
    assert_equal RateLimitedMailDeliveryJob, ActionMailer::MailDeliveryJob.descendants.first,
      'RateLimitedMailDeliveryJob should be the mail delivery job'
  end
end
