# frozen_string_literal: true

require 'rails_helper'
require 'zero_silent_failures/monitor'

RSpec.describe ZeroSilentFailures::Monitor do
  let(:service) { 'test-application' }
  let(:monitor) { described_class.new(service) }
  let(:call_location) { described_class::CallLocation.new('fake_func', 'fake_file', 'fake_line_42') }
  let(:tags) { ["service:#{service}", "function:#{call_location.base_label}"] }
  let(:user_account_uuid) { '123-test-uuid' }
  let(:additional_context) { { test: 'foobar' } }
  let(:payload) do
    {
      statsd: 'OVERRIDE',
      service:,
      function: call_location.base_label,
      file: call_location.path,
      line: call_location.lineno,
      user_account_uuid:,
      additional_context:
    }
  end

  describe '::CallLocation' do
    it 'responds to and returns expected values' do
      expect(call_location.base_label).to eq('fake_func')
      expect(call_location.path).to eq('fake_file')
      expect(call_location.lineno).to eq('fake_line_42')
    end
  end

  context 'with a call location provided' do
    describe '#log_silent_failure' do
      it 'logs a silent failure with call location' do
        payload[:statsd] = 'silent_failure'

        expect(StatsD).to receive(:increment).with('silent_failure', tags:)
        expect(Rails.logger).to receive(:error).with('Silent failure!', payload)

        monitor.log_silent_failure(additional_context, user_account_uuid, call_location:)
      end
    end

    describe '#log_silent_failure_avoided' do
      it 'logs a silent failure with call location and no confirmation' do
        payload[:statsd] = 'silent_failure_avoided_no_confirmation'

        expect(StatsD).to receive(:increment).with('silent_failure_avoided_no_confirmation', tags:)
        expect(Rails.logger).to receive(:error).with('Silent failure avoided (no confirmation)', payload)

        monitor.log_silent_failure_avoided(additional_context, user_account_uuid, call_location:)
      end
    end
  end
end
