# frozen_string_literal: true

require 'aes_256_cbc_encryptor'
require_relative '../../exceptions/vaos/exceptions/configuration_error'

module VAOS
  # ReferralEncryptionService handles the encryption and decryption of referral IDs
  # to prevent PII from appearing in URLs that are logged
  #
  # This service uses AES-256-CBC encryption with a URL-safe Base64 encoding
  # to ensure encrypted IDs can be used safely in URLs
  class ReferralEncryptionService
    # Encrypts a referral ID
    #
    # @param referral_id [String] The plain referral ID to encrypt
    # @return [String] URL-safe encrypted referral ID
    # @raise [VAOS::Exceptions::ConfigurationError] If an encryption error occurs
    def self.encrypt(referral_id)
      return nil if referral_id.blank?

      begin
        encryptor.encrypt(referral_id.to_s)
      rescue => e
        raise VAOS::Exceptions::ConfigurationError, e
      end
    end

    # Decrypts an encrypted referral ID
    #
    # @param encrypted_id [String] The encrypted referral ID
    # @return [String] The original plain referral ID
    # @raise [VAOS::Exceptions::ConfigurationError] If a decryption error occurs
    def self.decrypt(encrypted_id)
      return nil if encrypted_id.blank?

      begin
        encryptor.decrypt(encrypted_id)
      rescue => e
        raise VAOS::Exceptions::ConfigurationError, e
      end
    end

    # Creates and returns a configured instance of Aes256CbcEncryptor
    #
    # @return [Aes256CbcEncryptor] The configured encryptor
    # @raise [VAOS::Exceptions::ConfigurationError] If a configuration error occurs
    def self.encryptor
      settings = Settings.vaos.referral.encryption
      Thread.current[:vaos_referral_encryptor] ||= ::Aes256CbcEncryptor.new(settings.hex_secret, settings.hex_iv)
    rescue => e
      raise VAOS::Exceptions::ConfigurationError, e
    end
  end
end
