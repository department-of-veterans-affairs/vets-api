# frozen_string_literal: true

require 'common/client/base'
require 'evss/auth_headers'
require 'evss/mhvcf/configuration'
require 'evss/mhvcf/get_in_flight_forms_request_form'
require 'evss/mhvcf/mhv_consent_form_request_form'

module EVSS
  module MHVCF
    class Client < Common::Client::Base
      configuration EVSS::MHVCF::Configuration

      attr_accessor :auth_headers

      def user(user)
        @auth_headers = EVSS::AuthHeaders.new(user).to_hash
        self
      end

      # http://pint1.vaebnapp71.aac.va.gov:8001/wssweb/vii-app-1.2/rest/application.wadl/getInFlightFormsRequest
      def post_get_in_flight_forms
        form = EVSS::MHVCF::GetInFlightFormsRequestForm.new(form_type: '10-5345A-MHV')
        perform(:post, 'patientAuthService/1.2/getInFlightForms', form.params).body
        # returns object: http://pint1.vaebnapp71.aac.va.gov:8001/wssweb/vii-app-1.2/rest/application.wadl/getInFlightFormsResponse
      end

      def post_submit_form(params)
        form = EVSS::MHVCF::MHVConsentFormRequestForm.new(params)
        raise Common::Exceptions::ValidationErrors, form unless form.valid?
        perform(:post, 'formService/1.2/submitForm', form.params).body
      end

      # This is just used for testing / development purposes, there is no need to have
      # this available at runtime, so it is commented out for now
      def get_get_form_configs
        perform(:get, 'formService/1.2/getFormConfigs', nil).body
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
