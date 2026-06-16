require File.expand_path('../../test_helper', __FILE__)

class EmailQueueTest < ActiveSupport::TestCase
  fixtures :users, :projects, :members, :member_roles, :roles

  def setup
    @user = User.find(2)
    @project = Project.find(1)
    EmailQueue.delete_all
  end

  def test_enqueue_creates_record
    assert_difference 'EmailQueue.count', 1 do
      EmailQueue.enqueue('Mailer', 'test_email', 'smtp', [@user])
    end

    email = EmailQueue.last
    assert_equal 'Mailer', email.mailer_class
    assert_equal 'test_email', email.mailer_method
    assert_equal @user.mail, email.recipient_email
    assert_equal 0, email.retry_count
    assert_nil email.delivered_at
    assert_nil email.failed_at
  end

  def test_pending_scope
    delivered = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      delivered_at: Time.current
    )

    pending = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json
    )

    failed_but_retryable = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      retry_count: 5
    )

    assert_includes EmailQueue.pending.to_a, pending
    assert_includes EmailQueue.pending.to_a, failed_but_retryable
    assert_not_includes EmailQueue.pending.to_a, delivered
  end

  def test_mark_as_delivered
    email = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json
    )

    email.mark_as_delivered!
    email.reload

    assert_not_nil email.delivered_at
    assert_nil email.failed_at
  end

  def test_mark_as_failed
    email = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json
    )

    email.mark_as_failed!
    email.reload

    assert_not_nil email.failed_at
  end

  def test_increment_retry
    email = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      retry_count: 0
    )

    email.increment_retry!
    email.reload

    assert_equal 1, email.retry_count
  end

  def test_process_batch_limits_results
    20.times do |i|
      EmailQueue.create!(
        mailer_class: 'Mailer',
        mailer_method: 'test',
        delivery_method: 'smtp',
        serialized_args: [].to_json,
        created_at: i.minutes.ago
      )
    end

    EmailQueue.any_instance.stubs(:process).returns(true)
    count = EmailQueue.process_batch(15)

    assert_equal 15, count
  end

  def test_oldest_first_ordering
    newer = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      created_at: 1.minute.ago
    )

    older = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      created_at: 5.minutes.ago
    )

    emails = EmailQueue.pending.oldest_first.to_a
    assert_equal older.id, emails.first.id
  end

  def test_extract_recipient_email
    email = EmailQueue.extract_recipient_email([@user])
    assert_equal @user.mail, email
  end

  def test_serialize_and_deserialize_args
    args = [@user, @project, 'test string']
    serialized = EmailQueue.serialize_args(args)

    email = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: serialized
    )

    deserialized = email.send(:deserialize_args, serialized)

    assert_equal @user.id, deserialized[0].id
    assert_equal @project.id, deserialized[1].id
    assert_equal 'test string', deserialized[2]
  end

  def test_ready_to_send_includes_new_emails
    email = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      retry_count: 0
    )

    assert_includes EmailQueue.ready_to_send.to_a, email
  end

  def test_ready_to_send_respects_retry_delays
    # Email with 1 retry attempted 30 seconds ago - should NOT be ready (needs 1 minute)
    not_ready = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      retry_count: 1,
      last_attempted_at: 30.seconds.ago
    )

    # Email with 1 retry attempted 2 minutes ago - should be ready
    ready = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      retry_count: 1,
      last_attempted_at: 2.minutes.ago
    )

    ready_emails = EmailQueue.ready_to_send.to_a
    assert_not_includes ready_emails, not_ready
    assert_includes ready_emails, ready
  end

  def test_ready_to_send_with_different_retry_counts
    # 2 retries - needs 2 minutes
    email_2_retries = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      retry_count: 2,
      last_attempted_at: 3.minutes.ago
    )

    # 4 retries - needs 5 minutes
    email_4_retries_not_ready = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      retry_count: 4,
      last_attempted_at: 3.minutes.ago
    )

    email_4_retries_ready = EmailQueue.create!(
      mailer_class: 'Mailer',
      mailer_method: 'test',
      delivery_method: 'smtp',
      serialized_args: [].to_json,
      retry_count: 4,
      last_attempted_at: 6.minutes.ago
    )

    ready_emails = EmailQueue.ready_to_send.to_a
    assert_includes ready_emails, email_2_retries
    assert_not_includes ready_emails, email_4_retries_not_ready
    assert_includes ready_emails, email_4_retries_ready
  end

  def test_max_retry_count_is_5
    assert_equal 5, EmailQueue::MAX_RETRY_COUNT
  end
end
