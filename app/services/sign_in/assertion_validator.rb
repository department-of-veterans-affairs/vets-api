# frozen_string_literal: true

module SignIn
  class AssertionValidator
    attr_reader :assertion

    def initialize(assertion:)
      @assertion = assertion
    end

    def perform
      validate_service_account_config
      validate_iss
      validate_audience
      validate_scopes
      create_new_access_token
    end

    private

    def validate_service_account_config
      if service_account_config.blank?
        raise Errors::ServiceAccountConfigNotFound.new message: 'Service account config not found'
      end
    end

    def validate_iss
      if decoded_assertion.iss != audience
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Assertion issuer is not valid'
      end
    end

    def validate_audience
      unless decoded_assertion.aud.match(token_route)
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Assertion audience is not valid'
      end
    end

    def validate_scopes
      unless decoded_assertion_scopes_are_defined_in_config?
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Assertion scopes are not valid'
      end
    end

    def create_new_access_token
      ServiceAccountAccessToken.new(service_account_id:,
                                    audience:,
                                    scopes:,
                                    user_identifier:)
    end

    def decoded_assertion_scopes_are_defined_in_config?
      (scopes - service_account_config.scopes).empty?
    end

    def token_route
      "#{hostname}#{Constants::Auth::TOKEN_ROUTE_PATH}"
    end

    def hostname
      scheme = Settings.vsp_environment == 'localhost' ? 'http://' : 'https://'
      "#{scheme}#{Settings.hostname}"
    end

    def decoded_assertion
      @decoded_assertion ||= jwt_decode
    end

    def decoded_assertion_without_validation
      @decoded_assertion_without_validation ||= jwt_decode(with_validation: false)
    end

    def service_account_id
      @service_account_id ||= decoded_assertion_without_validation.service_account_id
    end

    def scopes
      @scopes ||= decoded_assertion.scopes
    end

    def user_identifier
      @user_identifier ||= decoded_assertion.sub
    end

    def audience
      @audience ||= service_account_config.access_token_audience
    end

    def service_account_config
      @service_account_config ||= ServiceAccountConfig.find_by(service_account_id:)
    end

    def jwt_decode(with_validation: true)
      assertion_public_keys = with_validation ? service_account_config.assertion_public_keys : nil
      decoded_jwt = JWT.decode(
        assertion,
        assertion_public_keys,
        with_validation,
        { verify_expiration: with_validation, algorithm: Constants::Auth::ASSERTION_ENCODE_ALGORITHM }
      )&.first
      OpenStruct.new(decoded_jwt)
    rescue JWT::VerificationError
      raise Errors::AssertionSignatureMismatchError.new message: 'Assertion body does not match signature'
    rescue JWT::ExpiredSignature
      raise Errors::AssertionExpiredError.new message: 'Assertion has expired'
    rescue JWT::DecodeError
      raise Errors::AssertionMalformedJWTError.new message: 'Assertion is malformed'
    end
  end
end
