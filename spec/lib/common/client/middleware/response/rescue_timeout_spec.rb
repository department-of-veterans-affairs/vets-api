# frozen_string_literal: true

require 'rails_helper'
require 'common/client/middleware/response/rescue_timeout'

describe Common::Client::Middleware::Response::RescueTimeout do
  subject do
    Faraday.new do |conn|
      conn.response :rescue_timeout, { backend_service: :evss }, 'api.hca.timeout'
      conn.adapter :test do |stub|
        stub.get('/') { [503, { body: 'it took too long!' }, 'timeout'] }
      end
    end
  end

  context 'receives a 503 response' do
    it 'should raise SentryIgnoredGatewayTimeout' do
      Settings.sentry.dsn = 'asdf'
      expect_any_instance_of(Common::Client::Middleware::Response::RescueTimeout).to(
        receive(:log_exception_to_sentry).with(
          Common::Exceptions::GatewayTimeout, { env_body: 'timeout' }, { backend_service: :evss }, :warn
        )
      )
      expect(StatsD).to receive(:increment).with('api.hca.timeout')
      expect { subject.get }.to raise_error(Common::Exceptions::SentryIgnoredGatewayTimeout)
      Settings.sentry.dsn = nil
    end
  end
end
