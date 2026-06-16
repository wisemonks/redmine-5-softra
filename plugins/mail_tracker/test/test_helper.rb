# Load the Redmine helper
require_relative '../../../test/test_helper'

# Configure ActiveJob to use test adapter for tests
# The test adapter supports delayed jobs (perform_later with wait)
ActiveJob::Base.queue_adapter = :test
