# frozen_string_literal: true

require 'common/client/base'
require 'token_validation/v2/configuration'

module AppealsApi
  # This is based on TokenValidation::V2::Client, but allows for more fine-grained status codes in failure responses
  class TokenValidationClient < ::Common::Client::Base
    configuration TokenValidation::V2::Configuration

    def initialize(api_key:)
      @api_key = api_key
    end

    def validate_token!(audience:, token:, scopes:)
      json = { 'aud': audience }
      headers = { 'apiKey': @api_key, 'Authorization': "Bearer #{token}" }

      response = perform(:post, 'v2/validation', json, headers)

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
