# frozen_string_literal: true

module SignIn
  class ServiceAccountAssertionValidator
    attr_reader :service_account_assertion, :service_account_config

    def initialize(service_account_assertion:, service_account_config:)
      @service_account_assertion = service_account_assertion
      @service_account_config = service_account_config
    end

    def perform
      validate_iss
      validate_audience
      validate_scopes
      decoded_service_account_assertion
    end

    private

    def validate_iss
      if decoded_service_account_assertion.iss != service_account_config.access_token_audience
        raise Errors::ServiceAccountAssertionAttributesError.new(
          message: 'Service account assertion issuer is not valid'
        )
      end
    end

    def validate_audience
      unless decoded_service_account_assertion.aud.match(token_route)
        raise Errors::ServiceAccountAssertionAttributesError.new(
          message: 'Service account assertion audience is not valid'
        )
      end
    end

    def validate_scopes
      unless (decoded_service_account_assertion.scopes - service_account_config.scopes).empty?
        raise Errors::ServiceAccountAssertionAttributesError.new(
          message: 'Service account assertion scopes are not valid'
        )
      end
    end

    def token_route
      "#{hostname}#{Constants::Auth::TOKEN_ROUTE_PATH}"
    end

    def hostname
      scheme = Settings.vsp_environment == 'localhost' ? 'http://' : 'https://'
      "#{scheme}#{Settings.hostname}"
    end

    def decoded_service_account_assertion
      @decoded_service_account_assertion ||= jwt_decode
    end

    def jwt_decode
      decoded_jwt = JWT.decode(
        service_account_assertion,
        service_account_config.service_account_assertion_public_keys,
        true,
        { verify_expiration: true, algorithm: Constants::Auth::CLIENT_ASSERTION_ENCODE_ALGORITHM }
      )&.first
      OpenStruct.new(decoded_jwt)
    rescue JWT::VerificationError
      raise Errors::ServiceAccountAssertionSignatureMismatchError.new(
        message: 'Service account assertion body does not match signature'
      )
    rescue JWT::ExpiredSignature
      raise Errors::ServiceAccountAssertionExpiredError.new message: 'Service account assertion has expired'
    rescue JWT::DecodeError
      raise Errors::ServiceAccountAssertionMalformedJWTError.new message: 'Service account assertion is malformed'
    end
  end
end
