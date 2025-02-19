# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::MonitoringService do
  subject { described_class.new(service_name) }

  let(:service_name) { 'test-service' }
  let(:monitor) { instance_double(Logging::Monitor) }

  before do
    allow(Logging::Monitor).to receive(:new).with(service_name).and_return(monitor)
    allow(monitor).to receive(:track)
  end

  describe '#track_event' do
    it 'calls monitor.track with correct parameters' do
      subject.track_event(:info, 'Test message', 'test.metric', ['test:tag'])
      expect(monitor).to have_received(:track).with(:info, 'Test message', 'test.metric', tags: ['test:tag'])
    end
  end

  describe '#track_error' do
    it 'calls monitor.track with error level and error class tag' do
      subject.track_error('Test error message', 'test.metric.error', 'TestError', ['test:tag'])
      expect(monitor).to have_received(:track).with(:error, 'Test error message', 'test.metric.error',
                                                    tags: ['test:tag', 'error:TestError'])
    end

    it 'calls monitor.track without error class if not provided' do
      subject.track_error('Test error message', 'test.metric.error')
      expect(monitor).to have_received(:track).with(:error, 'Test error message', 'test.metric.error', tags: [])
    end
  end
end
