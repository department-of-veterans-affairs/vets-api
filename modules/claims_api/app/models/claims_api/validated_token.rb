# frozen_string_literal: true

require 'rest-client'

module ClaimsApi
  class ValidatedToken
    def initialize(token_validation_url, token_string, audience)
      payload = { aud: audience }
      response = RestClient.post(token_validation_url,
                                 payload,
                                 { Authorization: "Bearer #{token_string}",
                                   apiKey: Settings.claims_api.token_validation.api_key })

      raise Common::Exceptions::TokenValidationError.new(detail: 'Token validation error') if response.nil?

      @validated_token_content = JSON.parse(response.body) if response.code == 200
      @validated_token_data = @validated_token_content['data']
      @validated_token_attributes = @validated_token_data['attributes']
      @is_valid_ccg_flow ||= @validated_token_attributes['cid'] == @validated_token_attributes['sub']
    end

    attr_reader :validated_token_data

    def client_credentials_token?
      @is_valid_ccg_flow
    end

    def payload
      @validated_token_attributes
    end
  end
end
