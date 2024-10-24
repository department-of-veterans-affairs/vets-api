# frozen_string_literal: true

require 'rails_helper'
require 'zero_silent_failures/monitor'
require 'logging/monitor'

RSpec.describe Logging::Monitor do
  let(:service) { 'test-application' }
  let(:monitor) { described_class.new(service) }
  let(:call_location) { double('Location', base_label: 'method_name', path: '/path/to/file.rb', lineno: 42) }
  let(:metric) { 'api.monitor.404' }
  let(:form_type) { '21P-50EZ' }
  let(:user_account_uuid) { '123-test-uuid' }
  let(:payload) do
    {
      statsd: 'OVERRIDE',
      user_account_uuid:,
      function: call_location.base_label,
      file: call_location.path,
      line: call_location.lineno
    }
  end

  context 'with a call location provided' do
    describe '#track_request' do
      it 'logs a request with call location' do
        payload[:statsd] = 'api.monitor.404'

        expect(StatsD).to receive(:increment).with('api.monitor.404')
        expect(Rails.logger).to receive(:error).with('21P-50EZ 404 Not Found!', payload)

        monitor.track_request('404 Not Found!', metric, form_type, user_account_uuid, call_location:)
      end
    end
  end
end
