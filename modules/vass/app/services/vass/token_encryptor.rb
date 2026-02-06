# frozen_string_literal: true

require 'active_support/message_encryptor'

module Vass
  ##
  # Service for encrypting and decrypting VASS OAuth tokens stored in Redis.
  #
  # Uses ActiveSupport::MessageEncryptor for authenticated encryption with AES-256-GCM.
  # Provides defense-in-depth security for service-to-service credentials.
  #
  # The encryption key should be:
  # - Stored in environment variable (vass__token_encryption_key)
  # - At least 32 bytes (256 bits) for AES-256
  # - Generated using: SecureRandom.hex(32)
  # - Different from other encryption keys in the application
  # - Never committed to the repository
  #
  class TokenEncryptor
    include Vass::Logging

    ##
    # Factory method to create a new TokenEncryptor instance.
    #
    # @return [Vass::TokenEncryptor] New instance
    #
    def self.build
      new
    end

    ##
    # Encrypts an OAuth token for secure storage in Redis.
    #
    # @param token [String, nil] OAuth token to encrypt
    # @return [String, nil] Encrypted token (Base64-encoded) or nil if token is nil
    # @raise [Vass::Errors::ConfigurationError] if encryption key is missing or invalid
    # @raise [Vass::Errors::EncryptionError] if encryption fails
    #
    def encrypt(token)
      return nil if token.nil?
      return token if token.empty?

      begin
        encryptor.encrypt_and_sign(token)
      rescue Vass::Errors::ConfigurationError
        # Let configuration errors propagate
        raise
      rescue => e
        log_vass_event(action: 'token_encryption_failed', level: :error, error_class: e.class.name)
        raise Vass::Errors::EncryptionError, "Failed to encrypt token: #{e.message}"
      end
    end

    ##
    # Decrypts an OAuth token retrieved from Redis.
    #
    # Handles backward compatibility:
    # - If decryption fails (e.g., plaintext token from before encryption was enabled),
    #   returns the input value and logs a warning.
    # - This allows graceful migration without requiring a cache flush.
    #
    # @param encrypted_token [String, nil] Encrypted token to decrypt
    # @return [String, nil] Decrypted token or nil if encrypted_token is nil
    # @raise [Vass::Errors::ConfigurationError] if encryption key is missing or invalid
    # @raise [Vass::Errors::DecryptionError] if decryption fails unexpectedly
    #
    def decrypt(encrypted_token)
      return nil if encrypted_token.nil?
      return encrypted_token if encrypted_token.empty?

      begin
        encryptor.decrypt_and_verify(encrypted_token)
      rescue Vass::Errors::ConfigurationError
        # Let configuration errors propagate
        raise
      rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveSupport::MessageEncryptor::InvalidMessage => e
        # Token might be plaintext from before encryption was enabled - allow backward compatibility
        log_vass_event(
          action: 'token_decryption_backward_compat',
          level: :warn,
          error_class: e.class.name,
          message: 'Attempting to decrypt potentially plaintext token - returning as-is for backward compatibility'
        )
        encrypted_token
      rescue => e
        log_vass_event(action: 'token_decryption_failed', level: :error, error_class: e.class.name)
        raise Vass::Errors::DecryptionError, "Failed to decrypt token: #{e.message}"
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
        secret = ActiveSupport::KeyGenerator.new(key).generate_key('vass-token-encryption', 32)
        ActiveSupport::MessageEncryptor.new(secret, cipher: 'aes-256-gcm')
      end
    end

    ##
    # Retrieves the encryption key from settings.
    #
    # @return [String, nil] Encryption key from environment
    #
    def encryption_key
      Settings.vass.token_encryption_key
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
              'VASS token encryption key is not configured. Set vass__token_encryption_key environment variable.'
      end

      # Minimum 32 characters for reasonable entropy (256 bits if hex)
      if key.length < 32
        raise Vass::Errors::ConfigurationError,
              "VASS token encryption key is too short (#{key.length} chars). Must be at least 32 characters."
      end
    end
  end
end
