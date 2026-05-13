namespace :email_queue do
  desc 'Process pending emails from the queue (15 per run)'
  task process: :environment do
    begin
      count = EmailQueue.process_batch(15)
      puts "[EmailQueue] Processed #{count} emails at #{Time.current}"
    rescue StandardError => e
      puts "[EmailQueue] Error processing emails: #{e.message}"
      Rails.logger.error("[EmailQueue] Error: #{e.message}\n#{e.backtrace.join("\n")}")
    end
  end

  desc 'Show email queue statistics'
  task stats: :environment do
    pending = EmailQueue.pending.count
    delivered = EmailQueue.delivered.count
    failed = EmailQueue.failed.count
    total = EmailQueue.count

    puts "Email Queue Statistics:"
    puts "  Total: #{total}"
    puts "  Pending: #{pending}"
    puts "  Delivered: #{delivered}"
    puts "  Failed: #{failed}"

    if pending > 0
      oldest = EmailQueue.pending.oldest_first.first
      puts "\nOldest pending email:"
      puts "  ID: #{oldest.id}"
      puts "  To: #{oldest.recipient_email}"
      puts "  Subject: #{oldest.subject}"
      puts "  Created: #{oldest.created_at}"
      puts "  Retry count: #{oldest.retry_count}"
    end
  end

  desc 'Clean up old delivered emails (older than 30 days)'
  task cleanup: :environment do
    cutoff = 30.days.ago
    count = EmailQueue.delivered.where('delivered_at < ?', cutoff).delete_all
    puts "[EmailQueue] Deleted #{count} old delivered emails"
  end

  desc 'Retry failed emails (reset failed status)'
  task retry_failed: :environment do
    count = EmailQueue.failed.update_all(failed_at: nil)
    puts "[EmailQueue] Reset #{count} failed emails for retry"
  end
end
