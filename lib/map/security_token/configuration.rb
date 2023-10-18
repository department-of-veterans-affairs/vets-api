# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/logging'

module MAP
  module SecurityToken
    class Configuration < Common::Client::Configuration::REST
      def base_path
        Settings.mobile_application_platform.oauth_url
      end

      def chatbot_client_id
        Settings.mobile_application_platform.chatbot_client_id
      end

      def sign_up_service_client_id
        Settings.mobile_application_platform.sign_up_service_client_id
      end

      def client_key_path
        Settings.mobile_application_platform.client_key_path
      end

      def client_cert_path
        Settings.mobile_application_platform.client_cert_path
      end

      def service_name
        'map_security_token_service'
      end

      def token_path
        'sts/oauth/v1/token'
      end

      def client_assertion_type
        'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
      end

      def grant_type
        'client_credentials'
      end

      def client_assertion_expiration_seconds
        300
      end

      def client_assertion_encode_algorithm
        'RS512'
      end

      def client_assertion_role
        'veteran'
      end

      def client_assertion_patient_id_type
        'icn'
      end

      def logging_prefix
        '[MAP][SecurityToken][Service]'
      end

      def client_assertion_private_key
        OpenSSL::PKey::RSA.new(File.read(client_key_path))
      end

      def client_assertion_certificate
        OpenSSL::X509::Certificate.new(File.read(client_cert_path))
      end

      def connection
        @connection ||= Faraday.new(
          base_path,
          headers: base_request_headers,
          request: request_options
        ) do |conn|
          conn.use :breakers
          conn.use Faraday::Response::RaiseError
          conn.response :betamocks if Settings.mobile_application_platform.secure_token_service.mock
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
