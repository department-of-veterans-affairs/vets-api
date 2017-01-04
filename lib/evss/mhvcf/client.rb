# frozen_string_literal: true

require 'common/client/base'
require 'evss/auth_headers'
require 'evss/mhvcf/configuration'
require 'evss/mhvcf/get_in_flight_forms_request_form'

module EVSS
  module MHVCF
    class Client < Common::Client::Base
      configuration EVSS::MHVCF::Configuration

      attr_accessor :auth_headers

      def user(user)
        @auth_headers = EVSS::AuthHeaders.new(user).to_hash
        self
      end

      def post_get_inflight_forms(params)
        form = EVSS::MHVCF::GetInFlightFormsRequestForm.new(params)
        raise Common::Exceptions::ValidationErrors, form unless form.valid?
        perform(:post, 'getInflightForms', form.params).body
      end

      private

      def perform(method, path, params, headers = nil)
        raise 'No User Authorization Header Provided' unless auth_headers.present?
        headers = (headers || {}).merge(@auth_headers)
        super(method, path, params, headers)
      end
    end
  end
end
