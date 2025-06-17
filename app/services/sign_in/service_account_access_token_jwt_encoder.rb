# frozen_string_literal: true

module SignIn
  class ServiceAccountAccessTokenJwtEncoder
    attr_reader :service_account_access_token

    def initialize(service_account_access_token:)
      @service_account_access_token = service_account_access_token
    end

    def perform
      jwt_encode_service_account_access_token
    end

    private

    def jwt_encode_service_account_access_token
      JWT.encode(payload, private_key, Constants::ServiceAccountAccessToken::JWT_ENCODE_ALGORITHM, jwt_header)
    end

    def payload
      {
        iss: Constants::ServiceAccountAccessToken::ISSUER,
        aud: service_account_access_token.audience,
        jti: service_account_access_token.uuid,
        sub: service_account_access_token.user_identifier,
        exp: service_account_access_token.expiration_time.to_i,
        iat: service_account_access_token.created_time.to_i,
        nbf: service_account_access_token.created_time.to_i,
        version: service_account_access_token.version,
        scopes: service_account_access_token.scopes,
        service_account_id: service_account_access_token.service_account_id,
        user_attributes: service_account_access_token.user_attributes
      }
    end

    def private_key
      OpenSSL::PKey::RSA.new(File.read(IdentitySettings.sign_in.jwt_encode_key))
    end

    def jwt_header
      {
        typ: 'JWT',
        kid: JWT::JWK.new(private_key).kid
      }
    end
  end
end
