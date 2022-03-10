# frozen_string_literal: true

module SignIn
  class AccessTokenJwtDecoder
    attr_reader :access_token_jwt

    def initialize(access_token_jwt:)
      @access_token_jwt = access_token_jwt
    end

    def perform(with_validation: true)
      decoded_token = jwt_decode_access_token(with_validation)
      SignIn::AccessToken.new(
        session_handle: decoded_token.session_handle,
        user_uuid: decoded_token.sub,
        refresh_token_hash: decoded_token.refresh_token_hash,
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
        private_key,
        with_validation,
        {
          verify_expiration: with_validation,
          algorithm: Constants::AccessToken::JWT_ENCODE_ALROGITHM
        }
      )&.first
      OpenStruct.new(decoded_jwt)
    rescue JWT::VerificationError
      raise SignIn::Errors::AccessTokenSignatureMismatchError
    rescue JWT::ExpiredSignature
      raise SignIn::Errors::AccessTokenExpiredError
    rescue JWT::DecodeError
      raise SignIn::Errors::AccessTokenMalformedJWTError
    end

    def private_key
      OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key))
    end
  end
end
