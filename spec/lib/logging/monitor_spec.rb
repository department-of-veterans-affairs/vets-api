# frozen_string_literal: true

require 'rails_helper'
require 'logging/monitor'

RSpec.describe Logging::Monitor do
  let(:service) { 'test-application' }
  let(:monitor) { described_class.new(service) }
  let(:call_location) { double('Location', base_label: 'method_name', path: '/path/to/file.rb', lineno: 42) }
  let(:metric) { 'api.monitor.404' }
  let(:additional_context) { { tags: ['form_id:21P-50EZ'], user_account_uuid: '123-test-uuid' } }
  let(:payload) do
    {
      statsd: 'OVERRIDE',
      service:,
      user_account_uuid: additional_context[:user_account_uuid],
      function: call_location.base_label,
      file: call_location.path,
      line: call_location.lineno,
      additional_context:
    }
  end

  context 'with a call location provided' do
    describe '#track_request' do
      it 'logs a request with call location' do
        payload[:statsd] = 'api.monitor.404'

        expect(StatsD).to receive(:increment).with('api.monitor.404',
                                                   { tags: ['form_id:21P-50EZ'] })
        expect(Rails.logger).to receive(:error).with('404 Not Found!', payload)

        monitor.track_request('error', '404 Not Found!', metric, additional_context, call_location:)
      end
    end
  end
end
