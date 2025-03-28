# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/logging'

module MAP
  module SignUp
    class Configuration < Common::Client::Configuration::REST
      def base_path
        IdentitySettings.map_services.sign_up_service_url
      end

      def provisioning_api_key
        IdentitySettings.map_services.sign_up_service_provisioning_api_key
      end

      def service_name
        'map_sign_up_service'
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

      def provisioning_acceptable_status
        [200, 406, 412]
      end

      def agreements_version_mapping
        {
          'v1' => 3
        }
      end

      def legal_display_version
        1.0
      end

      def logging_prefix
        '[MAP][SignUp][Service]'
      end

      def connection
        @connection ||= Faraday.new(
          base_path,
          headers: base_request_headers,
          request: request_options
        ) do |conn|
          conn.use(:breakers, service_name:)
          conn.use Faraday::Response::RaiseError
          conn.adapter Faraday.default_adapter
          conn.response :json, content_type: /\bjson/
          conn.response :betamocks if IdentitySettings.map_services.sign_up_service.mock
        end
      end
    end
  end
end
