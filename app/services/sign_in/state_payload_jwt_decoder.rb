# frozen_string_literal: true

module SignIn
  class StatePayloadJwtDecoder
    attr_reader :state_payload_jwt

    def initialize(state_payload_jwt:)
      @state_payload_jwt = state_payload_jwt
    end

    def perform
      create_state_payload
    end

    private

    def create_state_payload
      StatePayload.new(
        acr: decoded_jwt.acr,
        client_id: decoded_jwt.client_id,
        type: decoded_jwt.type,
        code_challenge: decoded_jwt.code_challenge,
        client_state: decoded_jwt.client_state,
        code: decoded_jwt.code,
        created_at: decoded_jwt.created_at,
        scope: decoded_jwt.scope,
        operation: decoded_jwt.operation
      )
    end

    def decoded_jwt
      @decoded_jwt ||= begin
        with_validation = true
        decoded_jwt = JWT.decode(
          state_payload_jwt,
          decode_key_array,
          with_validation,
          {
            algorithm: Constants::Auth::JWT_ENCODE_ALGORITHM
          }
        )&.first
        OpenStruct.new(decoded_jwt)
      end
    rescue JWT::VerificationError
      raise Errors::StatePayloadSignatureMismatchError.new message: 'State JWT body does not match signature'
    rescue JWT::DecodeError
      raise Errors::StatePayloadMalformedJWTError.new message: 'State JWT is malformed'
    end

    def decode_key_array
      [public_key, public_key_old].compact
    end

    def public_key
      OpenSSL::PKey::RSA.new(File.read(IdentitySettings.sign_in.jwt_encode_key)).public_key
    end

    def public_key_old
      return unless IdentitySettings.sign_in.jwt_old_encode_key

      OpenSSL::PKey::RSA.new(File.read(IdentitySettings.sign_in.jwt_old_encode_key)).public_key
    end
  end
end
