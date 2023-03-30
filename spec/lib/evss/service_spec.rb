# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Service do
  module EVSS::Foo
    class Configuration < EVSS::Configuration
      def base_path
        'http://'
      end

      def service_name
        'test_evss'
      end
    end

    class Service < EVSS::Service
      configuration Configuration
    end
  end

  let(:service) { EVSS::Foo::Service.new(build(:user)) }
  let(:transaction_id) { service.transaction_id }

  describe '#save_error_details' do
    it 'sets the tags_context and extra_context' do
      expect(Raven).to receive(:tags_context).with(external_service: 'evss/foo/service')
      expect(Raven).to receive(:extra_context).with(
        message: 'Common::Client::Errors::ClientError',
        url: 'http://',
        body: nil,
        transaction_id:
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
      headers = EVSS::AuthHeaders.new(build(:user)).to_h
      expect_any_instance_of(Common::Client::Base).to receive(:perform).with(:get, '', nil, headers, {})
                                                                       .and_return(OpenStruct.new(status: 200))
      EVSS::Foo::Service.new(nil, headers).perform(:get, '', nil, headers)
    end
  end
end
