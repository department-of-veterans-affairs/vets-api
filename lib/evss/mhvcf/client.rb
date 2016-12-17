# frozen_string_literal: true

require 'common/client/base'
require 'evss/auth_headers'
require 'evss/mhvcf/configuration'

module EVSS
  module MHVCF
    class Client < Common::Client::Base
      configuration EVSS::MHVCF::Configuration

      def user(user)
        @auth_headers = EVSS::AuthHeaders.new(user)
        self
      end

      def get_forms
        perform(:get, 'getInflightForms', nil).body
      end

      private

      def perform(method, path, params, headers = nil)
        raise 'No User Authorization Header Provided' unless @auth_headers.present?
        headers = (headers || {}).merge(@auth_headers)
        super(method, path, params, headers)
      end
    end
  end
end
