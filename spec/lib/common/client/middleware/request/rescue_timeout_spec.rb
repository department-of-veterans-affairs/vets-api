# frozen_string_literal: true

require 'rails_helper'

describe Common::Client::Middleware::Request::RescueTimeout do
  describe '#request' do
    subject do
      Faraday.new do |builder|
        builder.use Common::Client::Middleware::Request::RescueTimeout, 'EVSS502'
        builder.adapter :test do |stub|
          stub.get('/') { |_env| raise Faraday::TimeoutError }
        end
      end
    end

    context 'encounters Faraday::TimeoutError' do
      it 'should rescue Faraday::TimeoutError and raise' do
        Settings.sentry.dsn = 'asdf'
        expect_any_instance_of(Common::Client::Middleware::Request::RescueTimeout).to(
          receive(:log_exception_to_sentry).with(Exception, Hash, Hash, :warn)
        )
        expect { subject.get }.to raise_error(Common::Exceptions::BackendServiceException)
        Settings.sentry.dsn = nil
      end
    end
  end
end
