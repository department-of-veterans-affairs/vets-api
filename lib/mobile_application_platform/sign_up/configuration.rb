# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/logging'

module MobileApplicationPlatform
  module SignUp
    class Configuration < Common::Client::Configuration::REST
      def base_path
        Settings.mobile_application_platform.sign_up_service_url
      end

      def provisioning_api_key
        Settings.mobile_application_platform.sign_up_service_provisioning_api_key
      end

      def service_name
        'mobile_application_platform_sign_up_service'
      end

      def status_unauthenticated_path(icn)
        "/signup/v1/patients/#{icn}/status/summary"
      end

      def patients_agreements_path(icn)
        "/signup/v1/patients/#{icn}/agreements"
      end

      def patients_provisioning_path(icn)
        "/signup/v1/patients/#{icn}/provisioning/cerner"
      end

      def authenticated_header(jwt)
        { 'X-VAMF-JWT' => jwt }
      end

      def authenticated_provisioning_header
        { 'X-VAMF-API-KEY' => provisioning_api_key }
      end

      def logging_prefix
        '[MobileApplicationPlatform][SignUp][Service]'
      end

      def connection
        @connection ||= Faraday.new(
          base_path,
          headers: base_request_headers,
          request: request_options
        ) do |conn|
          conn.use :breakers
          conn.use Faraday::Response::RaiseError
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
