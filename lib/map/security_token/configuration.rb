# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/logging'

module MAP
  module SecurityToken
    class Configuration < Common::Client::Configuration::REST
      def base_path
        IdentitySettings.map_services.oauth_url
      end

      def chatbot_client_id
        IdentitySettings.map_services.chatbot_client_id
      end

      def sign_up_service_client_id
        IdentitySettings.map_services.sign_up_service_client_id
      end

      def check_in_client_id
        IdentitySettings.map_services.check_in_client_id
      end

      def appointments_client_id
        IdentitySettings.map_services.appointments_client_id
      end

      def client_key_path
        IdentitySettings.map_services.client_key_path
      end

      def client_cert_path
        IdentitySettings.map_services.client_cert_path
      end

      def jwks_cache_key
        'map_public_jwks'
      end

      def jwks_cache_expiration
        30.minutes
      end

      def public_jwks_path
        '/sts/oauth/v1/jwks'
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

      def log_prefix
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
          conn.use(:breakers, service_name:)
          conn.use Faraday::Response::RaiseError
          conn.adapter Faraday.default_adapter
          conn.response :json, content_type: /\bjson/
          conn.response :betamocks if IdentitySettings.map_services.secure_token_service.mock
        end
      end
    end
  end
end
