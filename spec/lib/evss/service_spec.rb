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

  describe '#save_error_details' do
    it 'should set the tags_context and extra_context' do
      expect(Raven).to receive(:tags_context).with(external_service: 'evss/foo/service')
      expect(Raven).to receive(:extra_context).with(
        message: 'Common::Client::Errors::ClientError',
        url: '/',
        body: nil
      )
      EVSS::Foo::Service.new(build(:user)).send(:save_error_details, Common::Client::Errors::ClientError.new)
    end
  end
end
