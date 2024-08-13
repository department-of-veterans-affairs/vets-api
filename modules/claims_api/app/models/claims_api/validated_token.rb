# frozen_string_literal: true

module ClaimsApi
  class ValidatedToken
    def initialize(token_validation_url, token_string, audience)
      @token_string = token_string

      payload = { aud: audience }

      response = call_token_validation_service(token_validation_url, payload)
      @validated_token_content = JSON.parse(response.body) if response.status == 200
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
      connection = Faraday.new(headers: request_headers, request: request_options)
      connection.post(token_validation_url, payload)
    rescue Faraday::Error => e
      error = JSON.parse(e.response.body)
      if !error['errors'].nil? && error['errors'].size.positive?
        err_detail = error['errors'][0]['detail']
        err_detail = 'Signature has expired' if err_detail.include?('expired')
        raise error_klass(err_detail)
      else
        raise error_klass('Token validation error')
      end
    end

    private

    def request_headers
      {
        Authorization: "Bearer #{@token_string}",
        apiKey: Settings.claims_api.token_validation.api_key
      }
    end

    def request_options
      {
        open_timeout: 15,
        timeout: 15
      }
    end
  end
end
