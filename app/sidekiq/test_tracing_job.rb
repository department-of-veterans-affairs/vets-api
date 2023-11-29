# frozen_string_literal: true

class TestTracingJob
  include Sidekiq::Job
  include TraceableTag
  service_tag :test_service
  
  def perform
    result = 22 + 20
    puts "Result is #{result}"
  end
end
