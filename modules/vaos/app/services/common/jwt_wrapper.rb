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
      # Log the claims that will be encoded
      current_claims = claims # Capture to avoid calling multiple times if it's expensive/has side effects
      puts "======== Common::JwtWrapper#sign_assertion DEBUG START ========"
      puts "[DEBUG] Claims to be encoded: #{current_claims.inspect}"
      puts "[DEBUG] Configured client_id from settings: '#{settings.client_id}'" # Re-verify this
      
      encoded_jwt = JWT.encode(current_claims, rsa_key, SIGNING_ALGORITHM, jwt_headers)
      
      puts "[DEBUG] Generated signed_assertion (JWT): #{encoded_jwt}"
      puts "[DEBUG] You can decode this JWT at https://jwt.io to inspect its payload."
      puts "[DEBUG] Look for 'iss' (issuer) or 'sub' (subject) claims for your client_id."
      puts "======== Common::JwtWrapper#sign_assertion DEBUG END ========"
      
      encoded_jwt # Return the original value
    rescue ConfigurationError => e
      puts "======== Common::JwtWrapper#sign_assertion CONFIGURATION ERROR ========"
      puts "[DEBUG] Error details: #{e.message}"
      if e.respond_to?(:errors) && e.errors.present?
        e.errors.each { |err| puts "[DEBUG]   Error Source Detail: #{err.try(:detail) || err.inspect}" }
      end
      puts "======== Common::JwtWrapper#sign_assertion DEBUG END (CONFIGURATION ERROR) ========"
      # Re-raise the original error type to ensure normal error handling proceeds
      raise VAOS::Exceptions::ConfigurationError.new(e, @config.service_name)
    rescue StandardError => e
      puts "======== Common::JwtWrapper#sign_assertion UNEXPECTED ERROR ========"
      puts "[DEBUG] Error type: #{e.class}"
      puts "[DEBUG] Error message: #{e.message}"
      puts "[DEBUG] Backtrace: #{e.backtrace.take(5).join("\n")}"
      puts "======== Common::JwtWrapper#sign_assertion DEBUG END (UNEXPECTED ERROR) ========"
      raise # Re-raise
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
