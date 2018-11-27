# frozen_string_literal: true

require 'rails_helper'

describe Common::Client::Middleware::Request::RescueTimeout do
  describe '#request' do
    subject do
      Faraday.new(Settings.hca.endpoint) do |builder|
        builder.request :rescue_timeout, { backend_service: :evss }, 'api.hca.timeout'
        builder.use     :breakers
        builder.adapter :test do |stub|
          stub.get('/') { |_env| raise Faraday::TimeoutError }
        end
      end
    end

    context 'encounters Faraday::TimeoutError' do
      before do
        Settings.sentry.dsn = 'asdf'
      end

      after do
        Settings.sentry.dsn = nil
      end

      it 'should rescue Faraday::TimeoutError and raise' do
        expect_any_instance_of(Common::Client::Middleware::Request::RescueTimeout).to(
          receive(:log_exception_to_sentry).with(Exception, Hash, Hash, :warn)
        )
        expect(StatsD).to receive(:increment).with(
          'api.external_http_request.HCA.failed', 1, tags: ['endpoint:/', 'method:get']
        )
        expect(StatsD).to receive(:increment).with('api.hca.timeout')
        expect { subject.get }.to raise_error(Common::Exceptions::SentryIgnoredGatewayTimeout)
      end

      it 'should not interfere with Breakers' do
        expect { subject.get }.to raise_error(Common::Exceptions::SentryIgnoredGatewayTimeout)
        expect { subject.get }.to raise_error(Breakers::OutageException)
      end
    end
  end
end
