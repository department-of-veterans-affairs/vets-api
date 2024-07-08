# frozen_string_literal: true

module SignIn
  class ServiceAccountAccessTokenJwtDecoder
    attr_reader :service_account_access_token_jwt

    def initialize(service_account_access_token_jwt:)
      @service_account_access_token_jwt = service_account_access_token_jwt
    end

    def perform(with_validation: true)
      decoded_token = jwt_decode_service_account_access_token(with_validation)
      ServiceAccountAccessToken.new(service_account_id: decoded_token.service_account_id,
                                    audience: decoded_token.aud,
                                    scopes: decoded_token.scopes,
                                    user_attributes: decoded_token.user_attributes,
                                    user_identifier: decoded_token.sub,
                                    uuid: decoded_token.jti,
                                    version: decoded_token.version,
                                    expiration_time: Time.zone.at(decoded_token.exp),
                                    created_time: Time.zone.at(decoded_token.iat))
    end

    private

    def jwt_decode_service_account_access_token(with_validation)
      decoded_jwt = JWT.decode(
        service_account_access_token_jwt,
        decode_key_array,
        with_validation,
        {
          verify_expiration: with_validation,
          algorithm: Constants::ServiceAccountAccessToken::JWT_ENCODE_ALGORITHM
        }
      )&.first
      OpenStruct.new(decoded_jwt)
    rescue JWT::VerificationError
      raise Errors::AccessTokenSignatureMismatchError.new(
        message: 'Service Account access token body does not match signature'
      )
    rescue JWT::ExpiredSignature
      raise Errors::AccessTokenExpiredError.new message: 'Service Account access token has expired'
    rescue JWT::DecodeError
      raise Errors::AccessTokenMalformedJWTError.new message: 'Service Account access token JWT is malformed'
    end

    def decode_key_array
      [public_key, public_key_old].compact
    end

    def public_key
      OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key)).public_key
    end

    def public_key_old
      return unless Settings.sign_in.jwt_old_encode_key

      OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_old_encode_key)).public_key
    end
  end
end
