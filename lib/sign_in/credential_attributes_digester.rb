# frozen_string_literal: true

module SignIn
  class CredentialAttributesDigester
    DIGEST_ALGORITHM = 'SHA256'

    def initialize(credential_attributes:)
      @credential_attributes = credential_attributes
    end

    def perform
      digest_credential_attributes
    rescue => e
      Rails.logger.error('[SignIn][CredentialAttributesDigester] Failed to digest user attributes', message: e.message)
      nil
    end

    private

    attr_reader :credential_attributes

    def digest_credential_attributes
      return if credential_attributes.blank?

      normalized_attributes = JSON.generate(normalize(credential_attributes))
      pepper = IdentitySettings.sign_in.credential_attributes_digester.pepper

      raise 'Pepper is not configured' if pepper.blank?

      OpenSSL::HMAC.hexdigest(DIGEST_ALGORITHM, pepper, normalized_attributes)
    end

    def normalize(attributes)
      case attributes
      when Hash
        attributes.deep_stringify_keys
                  .transform_values { |x| normalize(x) }
                  .sort.to_h
      when Array
        attributes.map { |e| normalize(e) }
      when Symbol
        attributes.to_s
      else
        attributes
      end
    end
  end
end
