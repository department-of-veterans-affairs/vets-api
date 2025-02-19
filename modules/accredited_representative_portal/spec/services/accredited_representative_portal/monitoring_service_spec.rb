# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::MonitoringService do
  subject { described_class.new(service_name) }

  let(:service_name) { 'test-service' }
  let(:monitor) { instance_double(Logging::Monitor) }
  let(:span) { instance_double(Datadog::Tracing::SpanOperation) }

  before do
    allow(Logging::Monitor).to receive(:new).with(service_name).and_return(monitor)
    allow(monitor).to receive(:track)

    # Mock Datadog APM Tracing
    allow(Datadog::Tracing).to receive(:trace).and_yield(span)
    allow(span).to receive(:service=)
    allow(span).to receive(:resource=)
    allow(span).to receive(:set_tag)
    allow(span).to receive(:set_error)
  end

  describe '#track_event' do
    it 'logs and traces an event' do
      subject.track_event(:info, 'Test message', 'test.metric', ['test:tag'])

      # Ensure monitor logs the event
      expect(monitor).to have_received(:track).with(:info, 'Test message', 'test.metric', tags: ['test:tag'])

      # Ensure Datadog tracing is applied
      expect(Datadog::Tracing).to have_received(:trace).with('test.metric')
      expect(span).to have_received(:set_tag).with('event.message', 'Test message')
      expect(span).to have_received(:set_tag).with('event.level', :info)
      expect(span).to have_received(:set_tag).with('event.tags', 'test:tag')
    end
  end

  describe '#track_error' do
    it 'logs and traces an error with error class' do
      subject.track_error('Test error message', 'test.metric.error', 'TestError', ['test:tag'])

      # Ensure monitor logs the error
      expect(monitor).to have_received(:track).with(:error, 'Test error message', 'test.metric.error',
                                                    tags: ['test:tag', 'error:TestError'])

      # Ensure Datadog tracing is applied
      expect(Datadog::Tracing).to have_received(:trace).with('test.metric.error')
      expect(span).to have_received(:set_error).with(instance_of(StandardError))
      expect(span).to have_received(:set_tag).with('error.class', 'TestError')
      expect(span).to have_received(:set_tag).with('error.tags', 'test:tag, error:TestError')
    end

    it 'logs and traces an error without an error class' do
      subject.track_error('Test error message', 'test.metric.error')

      # Ensure monitor logs the error
      expect(monitor).to have_received(:track).with(:error, 'Test error message', 'test.metric.error', tags: [])

      # Ensure Datadog tracing is applied
      expect(Datadog::Tracing).to have_received(:trace).with('test.metric.error')
      expect(span).to have_received(:set_error).with(instance_of(StandardError))
    end
  end

  describe '#with_tracing' do
    it 'starts a Datadog trace and yields a span' do
      expect { |b| subject.with_tracing('test.tracing', &b) }.to yield_with_args(span)

      expect(Datadog::Tracing).to have_received(:trace).with('test.tracing')
      expect(span).to have_received(:service=).with(service_name)
      expect(span).to have_received(:resource=).with('test.tracing')
    end
  end
end
