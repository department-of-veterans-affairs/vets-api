# frozen_string_literal: true

require 'concerns/traceable_tag'

class MockJob
  include Sidekiq::Job
  include TraceableTag
  service_tag :test_service

  def perform
    Rails.logger.info('Job performed!')
  end
end
