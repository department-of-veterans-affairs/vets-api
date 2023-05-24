# frozen_string_literal: true

module SignIn
  class ClientAssertionValidator
    attr_reader :client_assertion, :client_assertion_type, :client_config

    def initialize(client_assertion:, client_assertion_type:, client_config:)
      @client_assertion = client_assertion
      @client_assertion_type = client_assertion_type
      @client_config = client_config
    end

    def perform
      validate_client_assertion_type
      validate_iss
      validate_subject
      validate_audience
    end

    private

    def validate_client_assertion_type
      if client_assertion_type != Constants::Auth::CLIENT_ASSERTION_TYPE
        raise Errors::ClientAssertionTypeInvalidError.new message: 'Client assertion type is not valid'
      end
    end

    def validate_iss
      if decoded_client_assertion.iss != client_config.client_id
        raise Errors::ClientAssertionAttributesError.new message: 'Client assertion issuer is not valid'
      end
    end

    def validate_subject
      if decoded_client_assertion.sub != client_config.client_id
        raise Errors::ClientAssertionAttributesError.new message: 'Client assertion subject is not valid'
      end
    end

    def validate_audience
      unless decoded_client_assertion.aud.match(token_route)
        raise Errors::ClientAssertionAttributesError.new message: 'Client assertion audience is not valid'
      end
    end

    def token_route
      "#{hostname}#{Constants::Auth::TOKEN_ROUTE_PATH}"
    end

    def hostname
      scheme = Settings.vsp_environment == 'localhost' ? 'http://' : 'https://'
      "#{scheme}#{Settings.hostname}"
    end

    def decoded_client_assertion
      @decoded_client_assertion ||= jwt_decode
    end

    def jwt_decode(with_validation: true)
      decoded_jwt = JWT.decode(
        client_assertion,
        client_config.client_assertion_public_keys,
        with_validation,
        {
          verify_expiration: with_validation,
          algorithm: Constants::Auth::CLIENT_ASSERTION_ENCODE_ALGORITHM
        }
      )&.first
      OpenStruct.new(decoded_jwt)
    rescue JWT::VerificationError
      raise Errors::ClientAssertionSignatureMismatchError.new message: 'Client assertion body does not match signature'
    rescue JWT::ExpiredSignature
      raise Errors::ClientAssertionExpiredError.new message: 'Client assertion has expired'
    rescue JWT::DecodeError
      raise Errors::ClientAssertionMalformedJWTError.new message: 'Client assertion is malformed'
    end
  end
end
