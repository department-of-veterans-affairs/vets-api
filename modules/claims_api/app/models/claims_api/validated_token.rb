# frozen_string_literal: true

require 'rest-client'
require 'jwt'
require 'oidc/key_service'

module ClaimsApi
  class ValidatedToken
    def initialize(token_validation_url, token_string, audience)
      @token_string = token_string
      validate_jwt_values

      payload = { aud: audience }
      response = RestClient.post(token_validation_url,
                                 payload,
                                 { Authorization: "Bearer #{@token_string}",
                                   apiKey: Settings.claims_api.token_validation.api_key })

      raise Common::Exceptions::TokenValidationError.new(detail: 'Token validation error') if response.nil?

      @validated_token_content = JSON.parse(response.body) if response.code == 200
      @validated_token_data = @validated_token_content['data']
      @validated_token_attributes = @validated_token_data['attributes']
      @is_valid_ccg_flow ||= @validated_token_attributes['cid'] == @validated_token_attributes['sub']
    end

    attr_reader :validated_token_data

    def validate_jwt_values
      pubkey = public_key
      JWT.decode(@token_string, pubkey, true, algorithm: 'RS256')[0]
    rescue JWT::ExpiredSignature => e
      Rails.logger.info(e.message, token: @token_string)
      raise error_klass(e.message)
    rescue JWT::DecodeError => e
      raise error_klass(e.message)
    end

    def public_key
      decoded_token = JWT.decode(@token_string, nil, false, algorithm: 'RS256')
      iss = decoded_token[0]['iss']
      kid = decoded_token[1]['kid']
      key = OIDC::KeyService.get_key(kid, iss)
      if key.blank?
        StatsD.increment('okta_kid_lookup_failure', 1, tags: ["kid:#{kid}"])
        Rails.logger.info('Public key not found', kid:, exp: decoded_token[0]['exp'])
        raise error_klass("Public key not found for kid specified in token: '#{kid}'")
      end

      key
    rescue JWT::DecodeError => e
      raise error_klass("Unable to determine public key: #{e.message}")
    end

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
  end
end
