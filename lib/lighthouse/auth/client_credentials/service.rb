# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/auth/client_credentials/configuration'
require 'lighthouse/auth/client_credentials/jwt_generator'

module Auth
  module ClientCredentials
    class Service < Common::Client::Base
      configuration Auth::ClientCredentials::Configuration

      ##
      #
      # @param [String] token_url - URL of the token endpoint
      # @param [Array] api_scopes - List of requested API scopes
      # @param [String] client_id - ID used to identify the application
      # @param [String] aud_claim_url - The claim URL used as the 'aud' portion of the JWT
      # @param [String] rsa_key - RSA key used to encode the authentication JWT
      def initialize(token_url, api_scopes, client_id, aud_claim_url, rsa_key)
        @url = token_url
        @scopes = api_scopes
        @client_id = client_id
        @aud = aud_claim_url
        @rsa_key = rsa_key
        super()
      end

      ##
      # Request an access token
      #
      # @return [String] the access token needed to make requests
      #
      def get_token(auth_params = {})
        assertion = build_assertion
        request_body = build_request_body(assertion, @scopes, auth_params)
        res = config.get_access_token(@url, request_body)

        res.body['access_token']
      end

      private

      ##
      # @return [String] new JWT token
      #
      def build_assertion
        Auth::ClientCredentials::JWTGenerator.generate_token(@client_id, @aud, @rsa_key)
      end

      ##
      # @return [Hash] body of request to get access token
      #
      def build_request_body(assertion, scopes, auth_params = {})
        {
          grant_type: 'client_credentials',
          client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
          client_assertion: assertion,
          scope: scopes.join(' ')
        }.merge(auth_params)
      end
    end
  end
end
