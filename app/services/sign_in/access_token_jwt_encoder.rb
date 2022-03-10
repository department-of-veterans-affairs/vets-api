# frozen_string_literal: true

module SignIn
  class AccessTokenJwtEncoder
    attr_reader :access_token

    def initialize(access_token:)
      @access_token = access_token
    end

    def perform
      jwt_encode_access_token
    end

    private

    def payload
      {
        iss: Constants::AccessToken::ISSUER,
        aud: Constants::AccessToken::MOBILE_AUDIENCE,
        client_id: Constants::AccessToken::MOBILE_CLIENT_ID,
        jti: random_number,
        sub: access_token.user_uuid,
        exp: access_token.expiration_time.to_i,
        iat: access_token.created_time.to_i,
        session_handle: access_token.session_handle,
        refresh_token_hash: access_token.refresh_token_hash,
        parent_refresh_token_hash: access_token.parent_refresh_token_hash,
        anti_csrf_token: access_token.anti_csrf_token,
        last_regeneration_time: access_token.last_regeneration_time.to_i,
        version: access_token.version
      }
    end

    def random_number
      SecureRandom.hex
    end

    def jwt_encode_access_token
      JWT.encode(payload, private_key, Constants::AccessToken::JWT_ENCODE_ALROGITHM)
    end

    def private_key
      OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key))
    end
  end
end
