# frozen_string_literal: true

module SignIn
  class AccessTokenJwtDecoder
    attr_reader :access_token_jwt

    def initialize(access_token_jwt:)
      @access_token_jwt = access_token_jwt
    end

    def perform(with_validation: true)
      decoded_token = jwt_decode_access_token(with_validation)
      AccessToken.new(
        uuid: decoded_token.jti,
        session_handle: decoded_token.session_handle,
        client_id: decoded_token.client_id,
        user_uuid: decoded_token.sub,
        audience: decoded_token.aud,
        refresh_token_hash: decoded_token.refresh_token_hash,
        device_secret_hash: decoded_token.device_secret_hash,
        anti_csrf_token: decoded_token.anti_csrf_token,
        last_regeneration_time: Time.zone.at(decoded_token.last_regeneration_time),
        parent_refresh_token_hash: decoded_token.parent_refresh_token_hash,
        version: decoded_token.version,
        expiration_time: Time.zone.at(decoded_token.exp),
        created_time: Time.zone.at(decoded_token.iat)
      )
    end

    private

    def jwt_decode_access_token(with_validation)
      decoded_jwt = JWT.decode(
        access_token_jwt,
        decode_key_array,
        with_validation,
        {
          verify_expiration: with_validation,
          algorithm: Constants::AccessToken::JWT_ENCODE_ALGORITHM
        }
      )&.first
      OpenStruct.new(decoded_jwt)
    rescue JWT::VerificationError
      raise Errors::AccessTokenSignatureMismatchError.new message: 'Access token body does not match signature'
    rescue JWT::ExpiredSignature
      raise Errors::AccessTokenExpiredError.new message: 'Access token has expired'
    rescue JWT::DecodeError
      raise Errors::AccessTokenMalformedJWTError.new message: 'Access token JWT is malformed'
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
