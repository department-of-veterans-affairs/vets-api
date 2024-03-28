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
  let(:trace) { double('trace') }

  before do
    allow(Datadog::Tracing).to receive(:trace).and_return(trace)
  end

  context 'when the worker defines a trace_service_tag' do
    it 'sets the service tag on the active span to the worker’s trace_service_tag' do
      middleware.call(worker_instance, job, queue) do
        # simulate job execution
      end

      expect(Datadog::Tracing).to have_received(:trace).with(
        'sidekiq.job', { resource: nil, service: :test_service, span_type: 'worker' }
      ).at_least(:once)
    end
  end

  context 'when the worker does not define a trace_service_tag' do
    let(:mock_worker_class) do
      Class.new do
        include Sidekiq::Job

        def perform; end
      end
    end

    it 'sets the service tag on the active span to the default service tag' do
      middleware.call(worker_instance, job, queue) do
        # simulate job execution
      end

      expect(Datadog::Tracing).to have_received(:trace).with(
        'sidekiq.job', { resource: nil, service: 'vets-api-sidekiq', span_type: 'worker' }
      ).at_least(:once)
    end
  end
end
