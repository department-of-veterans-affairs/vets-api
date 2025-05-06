# frozen_string_literal: true

require 'sidekiq/semantic_logging'
require 'sidekiq/error_tag'
require 'sidekiq/testing'

Sidekiq::Testing.fake!
Sidekiq::Testing.server_middleware do |chain|
  chain.add Sidekiq::SemanticLogging
  chain.add SidekiqStatsInstrumentation::ServerMiddleware
  chain.add Sidekiq::ErrorTag
end

RSpec.configure do |config|
  config.before do
    Sidekiq::Job.clear_all
  end
end
