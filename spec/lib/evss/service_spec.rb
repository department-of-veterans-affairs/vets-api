# frozen_string_literal: true

require 'rails_helper'

describe EVSS::Service do
  module EVSS::Foo
    class Configuration < EVSS::Configuration
      def base_path
        '/'
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
        url: '/',	
        body: nil,
        transaction_id: transaction_id
      )
      service.send(:save_error_details, Common::Client::Errors::ClientError.new)
    end
  end
end
