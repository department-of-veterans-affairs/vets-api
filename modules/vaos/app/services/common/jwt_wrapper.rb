# frozen_string_literal: true

require_relative '../../exceptions/vaos/exceptions/configuration_error'

module Common
  class JwtWrapper
    SIGNING_ALGORITHM = 'RS512'

    class ConfigurationError < StandardError; end

    attr_reader :expiration, :settings

    delegate :key_path, :client_id, :kid, :audience_claim_url, to: :settings

    def initialize(service_settings, service_config)
      @settings = service_settings
      @config = service_config
      @expiration = 5
    end

    def sign_assertion
      JWT.encode(claims, rsa_key, SIGNING_ALGORITHM, jwt_headers)
    rescue ConfigurationError => e
      raise VAOS::Exceptions::ConfigurationError.new(e, @config.service_name)
    end

    def rsa_key
      raise ConfigurationError, 'RSA key path is not configured' if key_path.blank?

      raise ConfigurationError, "RSA key file not found at: #{key_path}" unless File.exist?(key_path)

      @rsa_key ||= begin
        OpenSSL::PKey::RSA.new(File.read(key_path))
      rescue => e
        raise ConfigurationError, "Failed to load RSA key: #{e.message}"
      end
    end

    private

    def claims
      {
        iss: client_id,
        sub: client_id,
        aud: audience_claim_url,
        iat: Time.zone.now.to_i,
        exp: expiration.minutes.from_now.to_i
      }
    end

    def jwt_headers
      {
        kid:,
        typ: 'JWT',
        alg: SIGNING_ALGORITHM
      }
    end
  end
end
