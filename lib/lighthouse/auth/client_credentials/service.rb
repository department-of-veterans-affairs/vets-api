# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/auth/client_credentials/configuration'
require 'lighthouse/auth/client_credentials/access_token_tracker'
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
      # @param [String] service_name - name to use when caching access token in Redis (Optional)
      # rubocop:disable Metrics/ParameterLists
      def initialize(token_url, api_scopes, client_id, aud_claim_url, rsa_key, service_name = nil)
        @url = token_url
        @scopes = api_scopes
        @client_id = client_id
        @aud = aud_claim_url
        @rsa_key = rsa_key
        @service_name = service_name

        @tracker = AccessTokenTracker
        super()
      end
      # rubocop:enable Metrics/ParameterLists

      ##
      # Request an access token
      #
      # @return [String] the access token needed to make requests
      #
      def get_token(auth_params = {})
        if @service_name.nil?
          res = get_new_token(auth_params)
          return res.body['access_token']
        end

        access_token = @tracker.get_access_token(@service_name)

        if access_token.nil?
          uuid = SecureRandom.uuid
          log_info(message: 'Access token expired. Fetching new token', service_name: @service_name, uuid:)

          res = get_new_token(auth_params)
          access_token = res.body['access_token']
          ttl = res.body['expires_in']
          @tracker.set_access_token(@service_name, access_token, ttl)

          log_info(message: "New access token deposited in Redis store with TTL: #{ttl}",
                   service_name: @service_name, uuid:)
        end

        access_token
      end

      private

      def get_new_token(auth_params = {})
        assertion = build_assertion
        request_body = build_request_body(assertion, @scopes, auth_params)
        config.get_access_token(@url, request_body)
      end

      def log_info(message:, service_name:, uuid:)
        ::Rails.logger.info({ message_type: 'Lighthouse CCG access token', message:, service_name:, uuid: })
      end

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
        auth_params = {} if auth_params.nil?
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
