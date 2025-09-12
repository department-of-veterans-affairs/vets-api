# frozen_string_literal: true

module SignIn
  class AssertionValidator < BaseAssertionValidator
    attr_reader :assertion, :decoded_assertion, :service_account_config

    def initialize(assertion:)
      super()
      @assertion = assertion
    end

    def perform
      @decoded_assertion = decode_assertion!(assertion)
      validate_issuer
      validate_scopes
      validate_user_attributes

      create_new_access_token
    end

    private

    delegate :service_account_id, to: :service_account_config

    def create_new_access_token
      ServiceAccountAccessToken.new(
        service_account_id:,
        audience: config_audience,
        scopes: assertion_scopes,
        user_attributes: assertion_user_attributes,
        user_identifier: assertion_user_identifier
      )
    end

    def validate_issuer
      if assertion_iss != service_account_id && assertion_iss != config_audience
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Invalid issuer'
      end
    end

    def validate_scopes
      return if assertion_scopes_in_config?

      raise Errors::ServiceAccountAssertionAttributesError.new message: 'Invalid scopes'
    end

    def validate_user_attributes
      if (assertion_user_attributes.keys.map(&:to_s) - service_account_config.access_token_user_attributes).any?
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Invalid user attributes'
      end
    end

    def jwt_decode_options
      {
        aud: [token_route],
        verify_aud: true,
        verify_iat: true,
        verify_expiration: true,
        required_claims: %w[iat sub exp iss],
        algorithms: [algorithm]
      }
    end

    def jwt_keyfinder(header, payload)
      @service_account_config = find_service_account_config(payload)
      super(header, payload)
    end

    def active_certs
      @active_certs ||= service_account_config.certs.active
    end

    def find_service_account_config(payload)
      service_account_id = payload['service_account_id'] || payload['iss']
      if service_account_id.blank?
        raise Errors::ServiceAccountAssertionAttributesError.new message: 'Invalid client identifier'
      end

      ServiceAccountConfig.find_by!(service_account_id:)
    rescue ActiveRecord::RecordNotFound
      raise Errors::ServiceAccountConfigNotFound.new message: 'Service account config not found'
    end

    def assertion_scopes_in_config?
      return service_account_config.scopes.blank? if assertion_scopes.blank?

      (assertion_scopes - service_account_config.scopes).empty?
    end

    def config_audience                 = service_account_config.access_token_audience
    def assertion_scopes                = Array(decoded_assertion[:scopes])
    def assertion_user_attributes       = decoded_assertion[:user_attributes] || {}
    def assertion_user_identifier       = decoded_assertion[:sub]
    def assertion_iss                   = decoded_assertion[:iss]
    def attributes_error_class          = Errors::ServiceAccountAssertionAttributesError
    def signature_mismatch_error_class  = Errors::AssertionSignatureMismatchError
    def expired_error_class             = Errors::AssertionExpiredError
    def malformed_error_class           = Errors::AssertionMalformedJWTError
  end
end
