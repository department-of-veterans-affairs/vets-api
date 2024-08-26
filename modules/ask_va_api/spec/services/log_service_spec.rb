# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LogService do
  subject(:logger) { described_class.new }

  let(:statsd) { instance_double(Datadog::Statsd) }
  let(:tracer) { class_double(Datadog::Tracing) }
  let(:span) { instance_double(Datadog::Tracing::Span) }

  before do
    allow(Datadog::Statsd).to receive(:new).and_return(statsd)
    allow(Datadog::Tracing).to receive(:tracer).and_return(tracer)
    allow(tracer).to receive(:trace).and_yield(span).and_return(span)
    allow(span).to receive(:set_tag)
    allow(span).to receive(:set_metric)
    allow(statsd).to receive(:timing)
    allow(Rails.logger).to receive(:error)
  end

  describe '#call' do
    let(:action) { 'test.action' }
    let(:tags) { { 'sample_key' => 'sample_value' } }

    context 'when the provided block runs without errors' do
      it 'sets the tags, metric, and finishes the span' do
        logger.call(action, tags:) { 'Success' }

        tags.each do |key, value|
          expect(span).to have_received(:set_tag).with(key, value)
        end
        expect(span).to have_received(:set_metric).with("#{action}.time", anything)
      end

      it 'returns the result of the block' do
        result = logger.call(action, tags:) { 'Success' }
        expect(result).to eq('Success')
      end
    end

    context 'when the provided block raises an error' do
      let(:error_message) { 'Sample Error' }

      before do
        allow(Sentry).to receive(:capture_exception)
      end

      it 'logs the error' do
        logger.call(action, tags:) { raise StandardError, error_message }
        expect(Rails.logger).to have_received(:error).with("Error logging action #{action}: #{error_message}")
      end

      it 'sets error tags on the span' do
        logger.call(action, tags:) { raise StandardError, error_message }
        expect(span).to have_received(:set_tag).with('error', true)
        expect(span).to have_received(:set_tag).with('error.msg', error_message)
      end

      it 'returns nil' do
        result = logger.call(action, tags:) { raise StandardError, error_message }
        expect(result).to be_nil
      end
    end
  end
end
