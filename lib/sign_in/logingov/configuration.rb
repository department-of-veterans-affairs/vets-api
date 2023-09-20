# frozen_string_literal: true

require 'common/client/configuration/rest'
require 'common/client/middleware/logging'

module SignIn
  module Logingov
    class Configuration < Common::Client::Configuration::REST
      def base_path
        Settings.logingov.oauth_url
      end

      def client_id
        Settings.logingov.client_id
      end

      def redirect_uri
        Settings.logingov.redirect_uri
      end

      def logout_redirect_uri
        Settings.logingov.logout_redirect_uri
      end

      def client_key_path
        Settings.logingov.client_key_path
      end

      def client_cert_path
        Settings.logingov.client_cert_path
      end

      def single_sign_out_uri
        Settings.logingov.sign_out_uri
      end

      def client_assertion_type
        'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'
      end

      def grant_type
        'authorization_code'
      end

      def client_assertion_expiration_seconds
        1000
      end

      def prompt
        'select_account'
      end

      def response_type
        'code'
      end

      def auth_path
        'openid_connect/authorize'
      end

      def token_path
        'api/openid_connect/token'
      end

      def logout_path
        'openid_connect/logout'
      end

      def userinfo_path
        'api/openid_connect/userinfo'
      end

      def public_jwks_path
        '/api/openid_connect/certs'
      end

      def jwt_decode_algorithm
        'RS256'
      end

      def ssl_key
        OpenSSL::PKey::RSA.new(File.read(client_key_path))
      end

      def ssl_cert
        OpenSSL::X509::Certificate.new(File.read(client_cert_path))
      end

      def log_credential
        false
      end

      def service_name
        'logingov'
      end

      def jwks_cache_key
        'logingov_public_jwks'
      end

      def jwks_cache_expiration
        30.minutes
      end

      def connection
        @connection ||= Faraday.new(
          base_path,
          headers: base_request_headers,
          request: request_options,
          ssl: { client_cert: ssl_cert,
                 client_key: ssl_key }
        ) do |conn|
          conn.use :breakers
          conn.use Faraday::Response::RaiseError
          conn.response :snakecase
          conn.response :json, content_type: /\bjson$/
          conn.adapter Faraday.default_adapter
        end
      end
    end
  end
end
