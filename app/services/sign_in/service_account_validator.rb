# frozen_string_literal: true

module SignIn
  class ServiceAccountValidator
    attr_reader :service_account_assertion, :grant_type, :decoded_account_assertion

    def initialize(service_account_assertion:, grant_type:)
      @service_account_assertion = service_account_assertion
      @grant_type = grant_type
    end

    def perform
      validations
      @decoded_service_account_assertion
    end

    private

    def validations
      validate_grant_type
      validate_service_account_assertion
    end

    def validate_grant_type
      if grant_type != Constants::Auth::JWT_BEARER
        raise Errors::GrantTypeValueError.new message: 'Grant Type is not valid'
      end
    end

    def validate_service_account_assertion
      @decoded_service_account_assertion = ServiceAccountAssertionValidator.new(service_account_assertion:,
                                                                                service_account_config:).perform
    end

    def service_account_config
      @service_account_config ||= source_service_account_config
    end

    def source_service_account_config
      jwt_payload = (JWT.decode service_account_assertion, nil, nil)
      service_account_id = jwt_payload.filter { |obj| obj.keys.include?('sub') }.pop['service_account_id']
      service_account_config = ServiceAccountConfig.find_by(service_account_id:)
      return service_account_config if service_account_config.present?

      raise Errors::ServiceAccountConfigNotFound.new message: 'Service account config not found'
    rescue JWT::DecodeError
      raise Errors::ServiceAccountAssertionMalformedJWTError.new message: 'Service account assertion is malformed'
    end
  end
end
