Sentry.init do |config|
  config.dsn = 'https://dce8603f6ea8841a230c875273b93e26@o17816.ingest.sentry.io/4506076804743168'
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]

  # Set traces_sample_rate to 1.0 to capture 100%
  # of transactions for performance monitoring.
  # We recommend adjusting this value in production.
  config.traces_sample_rate = 1.0
  # or
  config.traces_sampler = lambda do |context|
    true
  end
end