# frozen_string_literal: true

module SignIn
  class ServiceAccountAccessTokenJwtDecoder
    attr_reader :service_account_access_token_jwt

    def initialize(service_account_access_token_jwt:)
      @service_account_access_token_jwt = service_account_access_token_jwt
    end

    def perform
      jwt_decode_service_account_access_token
    end

    private

    def jwt_decode_service_account_access_token
      decoded_jwt = JWT.decode(
        service_account_access_token_jwt,
        private_key,
        true,
        {
          verify_expiration: true,
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

    def private_key
      OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key))
    end
  end
end
