# frozen_string_literal: true

module SignIn
  class AssertionValidator
    attr_reader :assertion

    def initialize(assertion:)
      @assertion = assertion
    end

    def perform
      validate_service_account_config
      validate_issuer
      validate_audience
      validate_scopes
      validate_user_attributes
      validate_subject
      validate_issued_at_time
      validate_expiration
      create_new_access_token
    end

    private

    def validate_service_account_config
      if service_account_config.blank?
        raise Errors::ServiceAccountConfigNotFound.new message: 'Service account config not found'
      end
    end

    def validate_issuer
      if issuer != audience
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Assertion issuer is not valid'
      end
    end

    def validate_audience
      unless assertion_audience.include?(token_route)
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Assertion audience is not valid'
      end
    end

    def validate_scopes
      unless decoded_assertion_scopes_are_defined_in_config?
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Assertion scopes are not valid'
      end
    end

    def validate_user_attributes
      if (user_attributes.keys.map(&:to_s) - service_account_config.access_token_user_attributes).any?
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Assertion user attributes are not valid'
      end
    end

    def validate_subject
      if user_identifier.blank?
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Assertion subject is not valid'
      end
    end

    def validate_issued_at_time
      if issued_at_time.blank? || issued_at_time > Time.now.to_i
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Assertion issuance timestamp is not valid'
      end
    end

    def validate_expiration
      if expiration.blank?
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Assertion expiration timestamp is not valid'
      end
    end

    def create_new_access_token
      ServiceAccountAccessToken.new(service_account_id:,
                                    audience:,
                                    scopes:,
                                    user_attributes:,
                                    user_identifier:)
    end

    def decoded_assertion_scopes_are_defined_in_config?
      return service_account_config.scopes.blank? if scopes.blank?

      (scopes - service_account_config.scopes).empty?
    end

    def token_route
      "#{hostname}#{Constants::Auth::TOKEN_ROUTE_PATH}"
    end

    def hostname
      return localhost_hostname if Settings.vsp_environment == 'localhost'
      return staging_hostname if Settings.review_instance_slug.present?

      "https://#{Settings.hostname}"
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
      @scopes ||= Array(decoded_assertion.scopes)
    end

    def user_attributes
      @user_attributes = decoded_assertion.user_attributes || {}
    end

    def user_identifier
      @user_identifier ||= decoded_assertion.sub
    end

    def issuer
      @issuer ||= decoded_assertion.iss
    end

    def assertion_audience
      @assertion_audience ||= Array(decoded_assertion.aud)
    end

    def audience
      @audience ||= service_account_config.access_token_audience
    end

    def issued_at_time
      @issued_at_time ||= decoded_assertion.iat
    end

    def expiration
      @expiration ||= decoded_assertion.exp
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

    def localhost_hostname
      port = URI.parse("http://#{Settings.hostname}").port

      "http://localhost:#{port}"
    end

    def staging_hostname
      'https://staging-api.va.gov'
    end
  end
end
