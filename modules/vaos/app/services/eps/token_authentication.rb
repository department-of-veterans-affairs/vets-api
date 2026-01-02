# frozen_string_literal: true

module Eps
  # TokenAuthentication provides common functionality for services that require
  # bearer token authentication. It handles token retrieval, caching, and header generation.
  module TokenAuthentication
    extend ActiveSupport::Concern

    included do
      # Returns a hash of HTTP headers including the authorization token and a unique correlation ID.
      # This method generates a new correlation ID for each call, enabling better tracing of individual
      # service requests within a single user request.
      #
      # @return [Hash] the HTTP headers with correlation ID
      def headers_with_correlation_id
        correlation_id = SecureRandom.uuid
        Rails.logger.info(message: 'EPS API Call', correlation_id:, request_id: RequestStore.store['request_id'],
                          controller: RequestStore.store['controller_name'],
                          station_number: user&.va_treatment_facility_ids&.first)

        {
          'Authorization' => "Bearer #{token}",
          'Content-Type' => 'application/json',
          'X-Request-ID' => correlation_id,
          'X-Parent-Request-ID' => RequestStore.store['request_id']
        }
      end

      # Retrieves a new token by making a POST request.
      # Parameters are appended to the URL.
      #
      # @return [Object] the token response from the API.
      def get_token
        with_monitoring do
          # Construct the full URL with query parameters
          url_with_params = "#{config.access_token_url}?#{token_params_for_url}"

          # Perform the POST request with params in URL and an empty body
          perform(:post,
                  url_with_params,
                  '', # Body is nil as params are in the URL
                  token_request_headers_for_curl)
        end
      end

      # Retrieves and caches the authentication token.
      # If a cached token is present, it is returned; otherwise, a new token is fetched.
      #
      # @return [String] the authentication token.
      def token
        Rails.cache.fetch(self.class::REDIS_TOKEN_KEY, expires_in: self.class::REDIS_TOKEN_TTL) do
          token_response = get_token
          parse_token_response(token_response)
        end
      end

      private

      # Parses the token response and extracts the access token.
      #
      # @param response [Object] the response object containing token data.
      # @return [String] the extracted access token.
      # @raise [TokenError] if the token response is invalid.
      def parse_token_response(response)
        raise TokenError, 'Invalid token response' if response.body.nil? || response.body[:access_token].blank?

        response.body[:access_token]
      end

      # Constructs the URL-encoded parameters for the token request (for URL appending).
      #
      # @return [String] the URL-encoded token parameters.
      def token_params_for_url
        URI.encode_www_form({
                              grant_type: config.grant_type,
                              scope: config.scopes,
                              client_assertion_type: config.client_assertion_type,
                              client_assertion: jwt_wrapper.sign_assertion
                            })
      end

      # Returns the HTTP headers to be used for the token request.
      #
      # @return [Hash] the token request headers.
      def token_request_headers_for_curl
        {
          'Content-Type' => 'application/x-www-form-urlencoded',
          'kid' => settings.kid
        }
      end

      # Retrieves or initializes the JwtWrapper instance for generating client assertions.
      #
      # @return [Common::JwtWrapper] the JWT wrapper instance.
      def jwt_wrapper
        @jwt_wrapper ||= Common::JwtWrapper.new(settings, config)
      end
    end

    # Exception raised when the token response is invalid.
    class TokenError < StandardError; end
  end
end
