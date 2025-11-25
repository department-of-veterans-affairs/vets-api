# frozen_string_literal: true

require 'rails_helper'
require 'logging/monitor'

RSpec.describe Logging::Monitor do
  let(:service) { 'test-application' }
  let(:allowlist) { %w[user_account_uuid document_id error errors tags form_id claim_id confirmation_number] }
  let(:monitor) { described_class.new(service, allowlist:) }
  let(:call_location) { double('Location', base_label: 'method_name', path: '/path/to/file.rb', lineno: 42) }
  let(:metric) { 'api.monitor.404' }
  let(:additional_context) do
    { tags: ['form_id:FORM_ID'], user_account_uuid: '123-test-uuid', document_id: 10, user_password: 'password123456' }
  end
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
        expect(Rails.logger).to receive(:error) do |_, payload|
          expect(payload[:context][:user_password]).to eq('[FILTERED]')
          expect(payload[:context][:user_account_uuid]).to eq('123-test-uuid')
          expect(payload[:context][:document_id]).to eq(10)
        end

        monitor.track_request('error', '404 Not Found!', metric, call_location:, **additional_context)
      end

      it 'logs an invalid log level' do
        tags = ["service:#{service}", "function:#{call_location.base_label}", 'form_id:FORM_ID']

        expect(StatsD).to receive(:increment).with(metric, tags:)
        expect(Rails.logger).to receive(:unknown).with('TEST', hash_including(service:))

        monitor.track_request('BAD_LOG_LEVEL', 'TEST', metric, call_location:, **additional_context)
      end

      it 'allows an "error" parameter' do
        tags = ["service:#{service}", "function:#{call_location.base_label}", 'form_id:FORM_ID']
        context = { error: 'Test error message', tags: }

        expect(StatsD).to receive(:increment).with(metric, tags:)
        expect(Rails.logger).to receive(:error) do |_, payload|
          expect(payload[:context][:error]).to eq('Test error message')
        end

        monitor.track_request('error', '404 Not Found!', metric, call_location:, **context)
      end

      it 'filters paramaters and redacts strings' do
        tags = ["service:#{service}", "function:#{call_location.base_label}", 'form_id:FORM_ID']
        context = {
          confirmation_number: 'SSN-123-45-6789', # NOT scrubbed, protected field
          user_account_uuid: 'uuid-with-phone-555-123-4567', # NOT scrubbed, protected field
          claim_id: 1,
          form_id: '12345',
          error: 'Error with SSN: 123-45-6789',
          errors: ['Phone: 555-123-4567', 'Email: user@example.com', 'ICN: 1234567890V123456',
                   'Credit card: 4444-4444-4444-4444'],
          icn: '1234567890V123456',
          debug_info: 'Credit card: 4444-4444-4444-4444',
          nested_info: [{ id: 1, foo: :bar }],
          tags:
        }

        expected = {
          confirmation_number: 'SSN-123-45-6789',
          user_account_uuid: 'uuid-with-phone-555-123-4567',
          claim_id: 1,
          form_id: '12345',
          error: 'Error with SSN: [REDACTED]',
          errors: ['Phone: [REDACTED]', 'Email: [REDACTED]', 'ICN: [REDACTED]', 'Credit card: [REDACTED]'],
          icn: '[FILTERED]',
          debug_info: '[FILTERED]',
          nested_info: '[FILTERED]',
          tags:
        }

        expect(StatsD).to receive(:increment).with(metric, tags:)
        expect(Rails.logger).to receive(:error) do |_, payload|
          expect(payload[:context]).to eq(expected)
        end

        monitor.track_request('error', '404 Not Found!', metric, call_location:, **context)
      end
    end
  end
end
