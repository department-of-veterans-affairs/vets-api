# frozen_string_literal: true

require 'common/client/base'
require 'token_validation/v2/configuration'

module AppealsApi
  # Exposes a subset of the data received from the token validation server
  #
  # @attr [Array<String>] scopes the scopes included with this token
  # @attr [String|nil] veteran_icn the ICN of the target veteran, if any
  TokenValidationResult = Struct.new(:scopes, :veteran_icn)

  class Configuration < ::TokenValidation::V2::Configuration
    def connection
      Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
        conn.use(:breakers, service_name:)
        conn.request :url_encoded # required for token validation service v3 (v2 accepted json)
        conn.response :snakecase
        conn.adapter Faraday.default_adapter
      end
    end
  end

  # This is based on TokenValidation::V2::Client, but allows for more fine-grained status codes in failure responses
  class TokenValidationClient < ::Common::Client::Base
    configuration Configuration

    def initialize(api_key:)
      @api_key = api_key
    end

    # Validates an OAuth token
    #
    # @param audience [String] the audience URL to use when validating the token (via well-known OpenID config)
    # @param token [String] the OAuth token provided by the user
    # @param scopes [Array<String>] valid scopes: the token is considered valid if it has any one of these scopes
    # @return [TokenValidationResult]
    # @raise [::Common::Exceptions::Unauthorized] if the token is rejected by the auth server
    # @raise [::Common::Exceptions::Forbidden] if the token has the wrong scope(s)
    def validate_token!(audience:, token:, scopes:)
      params = { aud: audience }
      headers = {
        apiKey: @api_key,
        Authorization: "Bearer #{token}",
        'Content-Type': 'application/x-www-form-urlencoded'
      }

      response = perform(:post, 'v3/validation', params, headers)

      raise ::Common::Exceptions::Unauthorized unless response.status == 200

      permitted = permitted_scopes(response)

      matching_scope = scopes.find { |scope| permitted.include?(scope) }

      raise ::Common::Exceptions::Forbidden if matching_scope.blank?

      body = JSON.parse(response.body)

      is_veteran_token = permitted.any? { |s| s.start_with? 'veteran/' }

      TokenValidationResult.new(
        scopes: permitted,
        veteran_icn: is_veteran_token ? body.dig('data', 'attributes', 'act', 'icn') : nil
      )
    end

    private

    def permitted_scopes(auth_server_response)
      JSON.parse(auth_server_response.body).dig('data', 'attributes', 'scp') || []
    end
  end
end
