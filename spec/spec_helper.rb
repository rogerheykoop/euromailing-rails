require "active_support"
require "active_support/core_ext"
require "active_job"
require "mail"
require "webmock/rspec"

require "euromailing"

ActiveJob::Base.queue_adapter = :test
ActiveJob::Base.logger = Logger.new(IO::NULL)

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random

  config.before do
    Euromailing.reset!
    Euromailing.configure { |c| c.api_key = "eml_live_test" }
    ActiveJob::Base.queue_adapter.enqueued_jobs.clear
  end
end
