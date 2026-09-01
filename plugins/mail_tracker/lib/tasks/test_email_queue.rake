namespace :email_queue do
  desc 'Test email queue by creating a test email'
  task test: :environment do
    user = User.active.first
    
    if user.nil?
      puts "No active users found"
      exit 1
    end

    puts "Creating test email for user: #{user.mail}"
    
    EmailQueue.enqueue(
      'Mailer',
      'test_email',
      'smtp',
      [user],
      nil
    )
    
    puts "Test email queued successfully!"
    puts "\nQueue statistics:"
    
    pending = EmailQueue.pending.count
    delivered = EmailQueue.delivered.count
    failed = EmailQueue.failed.count
    
    puts "  Pending: #{pending}"
    puts "  Delivered: #{delivered}"
    puts "  Failed: #{failed}"
    
    puts "\nRun 'rake email_queue:process' to process the queue"
  end

  desc 'Process a single email from the queue (for testing)'
  task process_one: :environment do
    email = EmailQueue.pending.oldest_first.first
    
    if email.nil?
      puts "No pending emails in queue"
      exit 0
    end
    
    puts "Processing email ##{email.id} to #{email.recipient_email}"
    email.process
    email.reload
    
    if email.delivered_at
      puts "✓ Email delivered successfully at #{email.delivered_at}"
    elsif email.failed_at
      puts "✗ Email failed: #{email.last_error}"
    else
      puts "⚠ Email not delivered (retry count: #{email.retry_count})"
    end
  end
end
