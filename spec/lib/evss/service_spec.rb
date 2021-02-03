# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Service do
  module EVSS::Foo
    class Configuration < EVSS::Configuration
      def base_path
        '/'
      end
    end

    class ConfigurationWithUri < EVSS::Configuration
      def base_path
        'http://test'
      end

      def service_name
        'test_evss'
      end
    end

    class Service < EVSS::Service
      configuration Configuration
    end

    class ServiceWithUri < EVSS::Service
      configuration ConfigurationWithUri
    end
  end

  let(:service) { EVSS::Foo::Service.new(build(:user)) }
  let(:transaction_id) { service.transaction_id }

  describe '#save_error_details' do
    it 'sets the tags_context and extra_context' do
      expect(Raven).to receive(:tags_context).with(external_service: 'evss/foo/service')
      expect(Raven).to receive(:extra_context).with(
        message: 'Common::Client::Errors::ClientError',
        url: '/',
        body: nil,
        transaction_id: transaction_id
      )
      service.send(:save_error_details, Common::Client::Errors::ClientError.new)
    end
  end

  describe 'initializes from headers' do
    it 'sets the transaction_id' do
      headers = EVSS::AuthHeaders.new(build(:user)).to_h
      expect(EVSS::Service.new(nil, headers).transaction_id).to eq(headers['va_eauth_service_transaction_id'])
    end

    it 'sets the user data from headers' do
      allow_any_instance_of(Faraday::Connection).to receive(:get)
      headers = EVSS::AuthHeaders.new(build(:user)).to_h
      service_from_headers = EVSS::Foo::ServiceWithUri.new(nil, headers)
      service_from_headers.perform(:get, 'test.test', nil, headers)
    end
  end
end
