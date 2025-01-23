# frozen_string_literal: true

require 'rails_helper'
require 'logging/monitor'

RSpec.describe Logging::Monitor do
  let(:service) { 'test-application' }
  let(:monitor) { described_class.new(service) }
  let(:call_location) { double('Location', base_label: 'method_name', path: '/path/to/file.rb', lineno: 42) }
  let(:metric) { 'api.monitor.404' }
  let(:additional_context) { { tags: ['form_id:FORM_ID'], user_account_uuid: '123-test-uuid' } }
  let(:payload) do
    {
      statsd: 'OVERRIDE',
      service:,
      function: call_location.base_label,
      file: call_location.path,
      line: call_location.lineno,
      context: additional_context
    }
  end

  context 'with a call location provided' do
    describe '#track_request' do
      it 'logs a request with call location' do
        payload[:statsd] = 'api.monitor.404'
        tags = ["service:#{service}", "function:#{call_location.base_label}", 'form_id:FORM_ID']

        expect(StatsD).to receive(:increment).with(metric, tags:)
        expect(Rails.logger).to receive(:error).with('404 Not Found!', payload)

        monitor.track_request('error', '404 Not Found!', metric, call_location:, **additional_context)
      end

      it 'logs an invalid log level' do
        error_level = 'BAD_LEVEL'
        tags = ["service:#{service}", "function:#{call_location.base_label}", 'form_id:FORM_ID']

        expect(StatsD).to receive(:increment).with(metric, tags:)
        expect(Rails.logger).to receive(:error).with("Invalid log error_level: #{error_level}")

        monitor.track_request(error_level, 'TEST', metric, call_location:, **additional_context)
      end
    end
  end
end
