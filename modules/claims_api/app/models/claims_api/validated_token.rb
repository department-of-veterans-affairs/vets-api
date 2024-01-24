# frozen_string_literal: true

require 'rest-client'

module ClaimsApi
  class ValidatedToken
    def initialize(token_validation_url, token_string, audience)
      @token_string = token_string

      payload = { aud: audience }

      response = call_token_validation_service(token_validation_url, payload)
      @validated_token_content = JSON.parse(response.body) if response.code == 200
      @validated_token_data = @validated_token_content['data']
      @validated_token_attributes = @validated_token_data['attributes']
      @is_valid_ccg_flow ||= @validated_token_attributes['cid'] == @validated_token_attributes['sub']
    end

    attr_reader :validated_token_data

    def error_klass(error_detail_string)
      # If there is an error validating the token, raise it here
      ::Common::Exceptions::TokenValidationError.new(detail: error_detail_string)
    end

    def client_credentials_token?
      @is_valid_ccg_flow
    end

    def payload
      @validated_token_attributes
    end

    def call_token_validation_service(token_validation_url, payload)
      RestClient.post(token_validation_url,
                      payload,
                      { Authorization: "Bearer #{@token_string}",
                        apiKey: Settings.claims_api.token_validation.api_key })
    rescue => e
      error = JSON.parse(e.response)
      if !error['errors'].nil? && error['errors'].size.positive?
        err_detail = error['errors'][0]['detail']
        err_detail = 'Signature has expired' if err_detail.include?('expired')
        raise error_klass(err_detail)
      else
        raise error_klass('Token validation error')
      end
    end
  end
end
