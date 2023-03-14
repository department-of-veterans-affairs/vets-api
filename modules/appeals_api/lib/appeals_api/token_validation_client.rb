# frozen_string_literal: true

require 'common/client/base'
require 'token_validation/v2/configuration'

module AppealsApi
  class TokenValidation
    module V3
      class Configuration < ::TokenValidation::V2::Configuration
        def connection
          Faraday.new(base_path, headers: base_request_headers, request: request_options) do |conn|
            conn.request :url_encoded # required for token validation service v3 (v2 accepted json)
            conn.response :snakecase
            conn.adapter Faraday.default_adapter
          end
        end
      end
    end
  end

  # This is based on TokenValidation::V2::Client, but allows for more fine-grained status codes in failure responses
  class TokenValidationClient < ::Common::Client::Base
    configuration TokenValidation::V3::Configuration

    def initialize(api_key:)
      @api_key = api_key
    end

    def validate_token!(audience:, token:, scopes:)
      params = { 'aud': audience }
      headers = {
        'apiKey': @api_key,
        'Authorization': "Bearer #{token}",
        'Content-Type': 'application/x-www-form-urlencoded'
      }

      response = perform(:post, 'v3/validation', params, headers)

      raise ::Common::Exceptions::Unauthorized unless response.status == 200

      permitted = permitted_scopes(response)

      matching_scope = scopes.find { |scope| permitted.include?(scope) }

      raise ::Common::Exceptions::Forbidden unless matching_scope
    end

    private

    def permitted_scopes(auth_server_response)
      JSON.parse(auth_server_response.body).dig('data', 'attributes', 'scp') || []
    end
  end
end
