# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/tracing_middleware'
require 'concerns/traceable_tag'

RSpec.describe Sidekiq::TracingMiddleware do
  let(:mock_worker_class) do
    Class.new do
      include Sidekiq::Job
      include TraceableTag
      service_tag :test_service

      def perform; end
    end
  end

  let(:middleware) { Sidekiq::TracingMiddleware.new }
  let(:worker_instance) { mock_worker_class.new }
  let(:job) { { 'class' => mock_worker_class.to_s } }
  let(:queue) { 'default' }
  let(:active_span) { double('active_span') }

  before do
    allow(Datadog::Tracing).to receive(:active_span).and_return(active_span)
    allow(active_span).to receive(:service=)
  end

  it 'sets the service tag on the active span to the worker’s trace_service_tag' do
    middleware.call(worker_instance, job, queue) do
      # simulate job execution
    end

    expect(Datadog::Tracing).to have_received(:active_span).at_least(:once)
    expect(active_span).to have_received(:service=).with(:test_service).at_least(:once)
  end

  it 'resets the service tag on the active span after the job is processed' do
    middleware.call(worker_instance, job, queue) do
      # simulate job execution
    end

    expect(active_span).to have_received(:service=).with(nil).at_least(:once)
  end
end
