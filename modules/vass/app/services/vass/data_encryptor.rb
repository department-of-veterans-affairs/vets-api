# frozen_string_literal: true

require 'active_support/message_encryptor'

module Vass
  ##
  # Service for encrypting and decrypting VASS PII data stored in Redis.
  #
  # Uses ActiveSupport::MessageEncryptor for authenticated encryption with AES-256-GCM.
  # Provides defense-in-depth security for sensitive veteran data including:
  # - OAuth tokens (service-to-service credentials)
  # - OTP data (last name, date of birth)
  # - Veteran metadata (EDIPI, veteran IDs)
  # - Session data (EDIPI, veteran IDs, JTI)
  # - Booking session data (appointment details)
  #
  # The encryption key should be:
  # - Stored in environment variable (vass__data_encryption_key)
  # - At least 32 bytes (256 bits) for AES-256
  # - Generated using: SecureRandom.hex(32)
  # - Different from other encryption keys in the application
  # - Never committed to the repository
  #
  class DataEncryptor
    include Vass::Logging

    ##
    # Factory method to create a new DataEncryptor instance.
    #
    # @return [Vass::DataEncryptor] New instance
    #
    def self.build
      new
    end

    ##
    # Encrypts data for secure storage in Redis.
    #
    # @param data [String, nil] Data to encrypt
    # @return [String, nil] Encrypted data (Base64-encoded) or nil if data is nil
    # @raise [Vass::Errors::ConfigurationError] if encryption key is missing or invalid
    # @raise [Vass::Errors::EncryptionError] if encryption fails
    #
    def encrypt(data)
      return nil if data.nil?
      return data if data.empty?

      begin
        encryptor.encrypt_and_sign(data)
      rescue Vass::Errors::ConfigurationError
        # Let configuration errors propagate
        raise
      rescue => e
        log_vass_event(action: 'data_encryption_failed', level: :error, error_class: e.class.name)
        raise Vass::Errors::EncryptionError, "Failed to encrypt data: #{e.message}"
      end
    end

    ##
    # Decrypts data retrieved from Redis.
    #
    # Handles backward compatibility:
    # - If decryption fails (e.g., plaintext data from before encryption was enabled),
    #   returns the input value and logs a warning.
    # - This allows graceful migration without requiring a cache flush.
    #
    # @param encrypted_data [String, nil] Encrypted data to decrypt
    # @return [String, nil] Decrypted data or nil if encrypted_data is nil
    # @raise [Vass::Errors::ConfigurationError] if encryption key is missing or invalid
    # @raise [Vass::Errors::DecryptionError] if decryption fails unexpectedly
    #
    def decrypt(encrypted_data)
      return nil if encrypted_data.nil?
      return encrypted_data if encrypted_data.empty?

      begin
        encryptor.decrypt_and_verify(encrypted_data)
      rescue Vass::Errors::ConfigurationError
        # Let configuration errors propagate
        raise
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage => e
        # Data might be plaintext from before encryption was enabled - allow backward compatibility
        log_vass_event(
          action: 'data_decryption_backward_compat',
          level: :warn,
          error_class: e.class.name,
          message: 'Attempting to decrypt potentially plaintext data - returning as-is for backward compatibility'
        )
        encrypted_data
      rescue => e
        log_vass_event(action: 'data_decryption_failed', level: :error, error_class: e.class.name)
        raise Vass::Errors::DecryptionError, "Failed to decrypt data: #{e.message}"
      end
    end

    private

    ##
    # Creates and configures the MessageEncryptor instance.
    #
    # @return [ActiveSupport::MessageEncryptor] Configured encryptor
    # @raise [Vass::Errors::ConfigurationError] if encryption key is missing or invalid
    #
    def encryptor
      @encryptor ||= begin
        key = encryption_key
        validate_encryption_key!(key)

        # Use AES-256-GCM for authenticated encryption (prevents tampering)
        # Key length must be 32 bytes for AES-256
        secret = ActiveSupport::KeyGenerator.new(key).generate_key('vass-data-encryption', 32)
        ActiveSupport::MessageEncryptor.new(secret, cipher: 'aes-256-gcm')
      end
    end

    ##
    # Retrieves the encryption key from settings.
    #
    # @return [String, nil] Encryption key from environment
    #
    def encryption_key
      Settings.vass.data_encryption_key
    end

    ##
    # Validates that the encryption key is present and meets minimum requirements.
    #
    # @param key [String, nil] Encryption key to validate
    # @raise [Vass::Errors::ConfigurationError] if key is missing or too short
    #
    def validate_encryption_key!(key)
      if key.blank?
        raise Vass::Errors::ConfigurationError,
              'VASS data encryption key is not configured. Set vass__data_encryption_key environment variable.'
      end

      # Minimum 32 characters for reasonable entropy (256 bits if hex)
      if key.length < 32
        raise Vass::Errors::ConfigurationError,
              "VASS data encryption key is too short (#{key.length} chars). Must be at least 32 characters."
      end
    end
  end
end
