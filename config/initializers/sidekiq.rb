# Sidekiq configuration for ActiveJob
begin
  require 'sidekiq'

  # Configure Sidekiq Redis connection
  Sidekiq.configure_server do |config|
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  end

  Sidekiq.configure_client do |config|
    config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  end

  # Set ActiveJob to use Sidekiq - this must run during initialization, not after
  Rails.application.config.active_job.queue_adapter = :sidekiq

  puts "[Sidekiq Initializer] Sidekiq configured as ActiveJob queue adapter"
rescue LoadError => e
  puts "[Sidekiq Initializer] Sidekiq not available: #{e.message}"
end
