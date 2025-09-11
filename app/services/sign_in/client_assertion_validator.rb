# frozen_string_literal: true

module SignIn
  class ClientAssertionValidator < BaseAssertionValidator
    attr_reader :client_assertion, :client_assertion_type, :client_config, :decoded_assertion

    def initialize(client_assertion:, client_assertion_type:, client_config:)
      super()
      @client_assertion = client_assertion
      @client_assertion_type = client_assertion_type
      @client_config = client_config
    end

    def perform
      validate_client_assertion_type
      @decoded_assertion = decode_assertion!(client_assertion)

      true
    end

    private

    def validate_client_assertion_type
      return if client_assertion_type == Constants::Urn::JWT_BEARER_CLIENT_AUTHENTICATION

      raise Errors::ClientAssertionTypeInvalidError.new message: 'Client assertion type is not valid'
    end

    def jwt_decode_options
      {
        aud: [token_route],
        sub: client_config.client_id,
        iss: client_config.client_id,
        verify_sub: true,
        verify_aud: true,
        verify_iss: true,
        verify_iat: true,
        verify_expiration: true,
        required_claims: %w[iat sub exp iss],
        algorithms: [algorithm]
      }
    end

    def active_certs
      @active_certs ||= client_config.certs.active
    end

    def attributes_error_class         = Errors::ClientAssertionAttributesError
    def signature_mismatch_error_class = Errors::ClientAssertionSignatureMismatchError
    def expired_error_class            = Errors::ClientAssertionExpiredError
    def malformed_error_class          = Errors::ClientAssertionMalformedJWTError
    def signature_mismatch_message     = 'Client assertion body does not match signature'
    def expired_message                = 'Client assertion has expired'
    def malformed_message              = 'Client assertion is malformed'
  end
end
