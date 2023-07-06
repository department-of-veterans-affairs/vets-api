# frozen_string_literal: true

module SignIn
  class ServiceAccountAccessTokenJwtEncoder
    attr_reader :decoded_service_account_assertion

    def initialize(decoded_service_account_assertion:)
      @decoded_service_account_assertion = decoded_service_account_assertion
    end

    def perform
      service_account_access_token
    end

    private

    def service_account_access_token
      @service_account_access_token ||= jwt_encode_access_token
    end

    def jwt_encode_access_token
      JWT.encode(payload, private_key, Constants::ServiceAccountAccessToken::JWT_ENCODE_ALGORITHM)
    end

    def payload
      {
        iss: "#{hostname}/#{Constants::ServiceAccountAccessToken::ISSUER}",
        aud: service_account_config.access_token_audience,
        jti: SecureRandom.hex,
        sub: decoded_service_account_assertion&.sub,
        iat: issued_at_time,
        exp: issued_at_time + service_account_config.access_token_duration.to_i,
        version: Constants::ServiceAccountAccessToken::CURRENT_VERSION,
        scopes: decoded_service_account_assertion.scopes
      }
    end

    def hostname
      scheme = Settings.vsp_environment == 'localhost' ? 'http://' : 'https://'
      "#{scheme}#{Settings.hostname}"
    end

    def issued_at_time
      Time.now.to_i
    end

    def service_account_config
      @service_account_config ||= source_service_account_config
    end

    def source_service_account_config
      service_account_config =
        ServiceAccountConfig.find_by(service_account_id: decoded_service_account_assertion.service_account_id)
      return service_account_config if service_account_config.present?

      raise Errors::ServiceAccountConfigNotFound.new message: 'Service account config not found'
    end

    def private_key
      OpenSSL::PKey::RSA.new(File.read(Settings.sign_in.jwt_encode_key))
    end
  end
end
