# frozen_string_literal: true

module Vass
  ##
  # Redis client for caching OAuth tokens, OTP codes, and session data.
  #
  # Handles:
  # - OAuth access token from Microsoft identity provider (shared across requests)
  # - One-Time Passwords (OTP) for veteran verification flow
  # - Session data (EDIPI, veteran_id) after successful OTP verification
  #
  class RedisClient
    include Vass::Logging

    attr_reader :settings

    ##
    # Factory method to create a new RedisClient instance.
    #
    # @return [Vass::RedisClient] New instance
    #
    def self.build
      new
    end

    def initialize
      @settings = Settings.vass
    end

    # ------------ Settings Accessors ------------
    # Note: Using explicit methods instead of delegate to avoid Ruby 3.3 warnings
    # about forwarding to private OpenStruct methods

    ##
    # Delegate expiry settings to @settings
    delegate :redis_token_expiry, :redis_otp_expiry, :redis_session_expiry, to: :@settings

    # ------------ OAuth Token Management ------------

    ##
    # Retrieves the cached OAuth access token and decrypts it.
    #
    # @return [String, nil] Cached OAuth token (decrypted) or nil if not present/expired
    #
    def token
      encrypted_token = with_redis_error_handling do
        Rails.cache.read(
          'oauth_token',
          namespace: 'vass-auth-cache'
        )
      end

      return nil if encrypted_token.nil?

      token_encryptor.decrypt(encrypted_token)
    end

    ##
    # Encrypts and saves the OAuth access token to cache with expiration.
    #
    # @param token [String, nil] OAuth token to cache (nil clears the cache)
    # @return [Boolean] true if write succeeds
    #
    def save_token(token:)
      encrypted_token = token.nil? ? nil : token_encryptor.encrypt(token)

      with_redis_error_handling do
        Rails.cache.write(
          'oauth_token',
          encrypted_token,
          namespace: 'vass-auth-cache',
          expires_in: redis_token_expiry
        )
      end
    end

    # ------------ One-Time Password (OTP) Management ------------

    ##
    # Saves an OTP for a veteran UUID with short expiration.
    # Stores the code along with identity data for validation during authentication.
    #
    # @param uuid [String] Veteran UUID
    # @param code [String] One-time password
    # @param last_name [String] Veteran's last name (for identity verification)
    # @param dob [String] Veteran's date of birth (for identity verification)
    # @return [Boolean] true if write succeeds
    #
    def save_otp(uuid:, code:, last_name:, dob:)
      otp_data = {
        code:,
        last_name:,
        dob:
      }

      with_redis_error_handling do
        Rails.cache.write(
          otp_key(uuid),
          Oj.dump(otp_data),
          namespace: 'vass-otp-cache',
          expires_in: redis_otp_expiry
        )
      end
    end

    ##
    # Retrieves stored OTP data (code and identity info) by UUID.
    #
    # @param uuid [String] Veteran UUID from email link
    # @return [Hash, nil] Hash with :code, :last_name, :dob or nil if not found/expired
    #
    def otp_data(uuid:)
      cached = with_redis_error_handling do
        Rails.cache.read(
          otp_key(uuid),
          namespace: 'vass-otp-cache'
        )
      end

      return nil if cached.nil?

      begin
        Oj.load(cached, symbol_keys: true)
      rescue Oj::ParseError
        log_vass_event(action: 'json_parse_failed', level: :error, key_type: 'otp_data')
        nil
      end
    end

    ##
    # Deletes an OTP after successful verification (one-time use).
    #
    # @param uuid [String] Veteran UUID
    # @return [void]
    #
    def delete_otp(uuid:)
      with_redis_error_handling do
        Rails.cache.delete(
          otp_key(uuid),
          namespace: 'vass-otp-cache'
        )
      end
    end

    ##
    # Saves veteran metadata (edipi, veteran_id, email) keyed by UUID.
    # Used to avoid fetching veteran data again in the show flow.
    #
    # @param uuid [String] Veteran UUID
    # @param edipi [String] Veteran EDIPI
    # @param veteran_id [String] Veteran ID
    # @param email [String, nil] Veteran email address (optional)
    # @return [Boolean] true if write succeeds
    #
    def save_veteran_metadata(uuid:, edipi:, veteran_id:, email: nil)
      metadata = {
        edipi:,
        veteran_id:,
        email:
      }

      with_redis_error_handling do
        Rails.cache.write(
          veteran_metadata_key(uuid),
          Oj.dump(metadata),
          namespace: 'vass-otp-cache',
          expires_in: redis_otp_expiry
        )
      end
    end

    ##
    # Retrieves veteran metadata by UUID.
    #
    # @param uuid [String] Veteran UUID
    # @return [Hash, nil] Metadata hash with edipi and veteran_id, or nil if not found/expired
    #
    def veteran_metadata(uuid:)
      cached = with_redis_error_handling do
        Rails.cache.read(
          veteran_metadata_key(uuid),
          namespace: 'vass-otp-cache'
        )
      end

      return nil if cached.nil?

      begin
        Oj.load(cached).with_indifferent_access
      rescue Oj::ParseError
        log_vass_event(action: 'json_parse_failed', level: :error, key_type: 'veteran_metadata')
        nil
      end
    end

    # ------------ Booking Session Management ------------

    ##
    # Stores appointment booking session data during multi-step booking flow.
    # Used to track appointmentId and selected slot across API calls.
    #
    # @param veteran_id [String] Veteran ID (UUID)
    # @param data [Hash] Booking session data
    #   - appointment_id [String] Cohort appointment ID
    #   - time_start_utc [String, nil] Selected slot start time (added in step 3)
    #   - time_end_utc [String, nil] Selected slot end time (added in step 3)
    # @return [Boolean] true if write succeeds
    #
    def store_booking_session(veteran_id:, data:)
      with_redis_error_handling do
        Rails.cache.write(
          booking_session_key(veteran_id),
          data,
          namespace: 'vass-booking-cache',
          expires_in: Settings.vass.booking_session_expiry || 3600
        )
      end
    end

    ##
    # Retrieves appointment booking session data.
    #
    # @param veteran_id [String] Veteran ID (UUID)
    # @return [Hash] Booking session data or empty hash if not found
    #
    def get_booking_session(veteran_id:)
      with_redis_error_handling do
        Rails.cache.read(
          booking_session_key(veteran_id),
          namespace: 'vass-booking-cache'
        )
      end || {}
    end

    ##
    # Updates appointment booking session data (merges with existing).
    #
    # @param veteran_id [String] Veteran ID (UUID)
    # @param data [Hash] Additional data to merge
    # @return [Boolean] true if write succeeds
    #
    def update_booking_session(veteran_id:, data:)
      current_data = get_booking_session(veteran_id:)
      store_booking_session(veteran_id:, data: current_data.merge(data))
    end

    ##
    # Deletes appointment booking session data (after successful save or cancellation).
    #
    # @param veteran_id [String] Veteran ID (UUID)
    # @return [void]
    #
    def delete_booking_session(veteran_id:)
      with_redis_error_handling do
        Rails.cache.delete(
          booking_session_key(veteran_id),
          namespace: 'vass-booking-cache'
        )
      end
    end

    # ------------ Session Management ------------

    ##
    # Saves session data after successful OTP verification.
    # Stores EDIPI, veteran_id, and active jti for use in subsequent VASS API calls.
    # Session is keyed by UUID (one session per veteran). Storing the jti ensures
    # only the most recently issued token is valid - previous tokens are invalidated.
    #
    # @param uuid [String] Veteran UUID from email link
    # @param jti [String] JWT ID of the currently valid token
    # @param edipi [String] Veteran EDIPI (required for VASS API headers)
    # @param veteran_id [String] Veteran ID in VASS system
    # @return [Boolean] true if write succeeds
    #
    def save_session(uuid:, jti:, edipi:, veteran_id:)
      session_data = {
        jti:,
        edipi:,
        veteran_id:
      }

      with_redis_error_handling do
        Rails.cache.write(
          session_key(uuid),
          Oj.dump(session_data),
          namespace: 'vass-session-cache',
          expires_in: redis_session_expiry
        )
      end
    end

    ##
    # Retrieves session data by UUID.
    #
    # @param uuid [String] Veteran UUID
    # @return [Hash, nil] Session data hash or nil if not found/expired/revoked
    #
    def session(uuid:)
      cached = with_redis_error_handling do
        Rails.cache.read(
          session_key(uuid),
          namespace: 'vass-session-cache'
        )
      end

      return nil if cached.nil?

      begin
        Oj.load(cached).with_indifferent_access
      rescue Oj::ParseError
        log_vass_event(action: 'json_parse_failed', level: :error, key_type: 'session_data')
        nil
      end
    end

    ##
    # Checks if a session exists for the given UUID.
    # Used to verify token has not been revoked.
    #
    # @param uuid [String] Veteran UUID
    # @return [Boolean] true if session exists
    #
    def session_exists?(uuid:)
      session(uuid:).present?
    end

    ##
    # Checks if the given jti is the active token for this session.
    # Returns false if session doesn't exist or jti doesn't match.
    # This ensures only the most recently issued token is valid.
    #
    # @param uuid [String] Veteran UUID
    # @param jti [String] JWT ID to validate
    # @return [Boolean] true if jti matches the active session token
    #
    def session_valid_for_jti?(uuid:, jti:)
      session_data = session(uuid:)
      return false unless session_data

      session_data[:jti] == jti
    end

    ##
    # Retrieves EDIPI from session for use in VASS API headers.
    #
    # @param uuid [String] Veteran UUID
    # @return [String, nil] EDIPI or nil if session not found
    #
    def edipi(uuid:)
      session_data = session(uuid:)
      session_data&.dig(:edipi)
    end

    ##
    # Retrieves veteran_id from session for use in VASS API calls.
    #
    # @param uuid [String] Veteran UUID
    # @return [String, nil] Veteran ID or nil if session not found
    #
    def veteran_id(uuid:)
      session_data = session(uuid:)
      session_data&.dig(:veteran_id)
    end

    ##
    # Deletes session data (token revocation/logout).
    #
    # @param uuid [String] Veteran UUID
    # @return [Boolean] true if deletion succeeds
    #
    def delete_session(uuid:)
      with_redis_error_handling do
        Rails.cache.delete(
          session_key(uuid),
          namespace: 'vass-session-cache'
        )
      end
    end

    # ------------ Rate Limiting ------------

    ##
    # Retrieves the current rate limit count for an identifier.
    #
    # @param identifier [String] UUID to rate limit (rate limited per veteran)
    # @return [Integer] Current attempt count
    #
    def rate_limit_count(identifier:)
      with_redis_error_handling do
        Rails.cache.read(
          rate_limit_key(identifier),
          namespace: 'vass-rate-limit-cache'
        )
      end.to_i
    end

    ##
    # Increments the rate limit counter for an identifier.
    #
    # @param identifier [String] UUID to rate limit (rate limited per veteran)
    # @return [Integer] New attempt count
    #
    def increment_rate_limit(identifier:)
      current = rate_limit_count(identifier:)
      new_count = current + 1

      with_redis_error_handling do
        Rails.cache.write(
          rate_limit_key(identifier),
          new_count,
          namespace: 'vass-rate-limit-cache',
          expires_in: rate_limit_expiry
        )
      end

      new_count
    end

    ##
    # Checks if the identifier has exceeded the rate limit.
    #
    # @param identifier [String] UUID to check (rate limited per veteran)
    # @return [Boolean] true if rate limit exceeded
    #
    def rate_limit_exceeded?(identifier:)
      rate_limit_count(identifier:) >= rate_limit_max_attempts
    end

    ##
    # Resets the rate limit counter for an identifier.
    #
    # @param identifier [String] UUID to reset (rate limited per veteran)
    # @return [void]
    #
    def reset_rate_limit(identifier:)
      with_redis_error_handling do
        Rails.cache.delete(
          rate_limit_key(identifier),
          namespace: 'vass-rate-limit-cache'
        )
      end
    end

    # ------------ Validation Rate Limiting ------------

    ##
    # Retrieves the current validation rate limit count for an identifier.
    #
    # @param identifier [String] UUID to rate limit (rate limited per veteran)
    # @return [Integer] Current attempt count
    #
    def validation_rate_limit_count(identifier:)
      with_redis_error_handling do
        Rails.cache.read(
          validation_rate_limit_key(identifier),
          namespace: 'vass-rate-limit-cache'
        )
      end.to_i
    end

    ##
    # Increments the validation rate limit counter for an identifier.
    #
    # @param identifier [String] UUID to rate limit (rate limited per veteran)
    # @return [Integer] New attempt count
    #
    def increment_validation_rate_limit(identifier:)
      current = validation_rate_limit_count(identifier:)
      new_count = current + 1

      with_redis_error_handling do
        Rails.cache.write(
          validation_rate_limit_key(identifier),
          new_count,
          namespace: 'vass-rate-limit-cache',
          expires_in: rate_limit_expiry
        )
      end

      new_count
    end

    ##
    # Checks if the identifier has exceeded the validation rate limit.
    #
    # @param identifier [String] UUID to check (rate limited per veteran)
    # @return [Boolean] true if rate limit exceeded
    #
    def validation_rate_limit_exceeded?(identifier:)
      validation_rate_limit_count(identifier:) >= rate_limit_max_attempts
    end

    ##
    # Resets the validation rate limit counter for an identifier.
    #
    # @param identifier [String] UUID to reset (rate limited per veteran)
    # @return [void]
    #
    def reset_validation_rate_limit(identifier:)
      with_redis_error_handling do
        Rails.cache.delete(
          validation_rate_limit_key(identifier),
          namespace: 'vass-rate-limit-cache'
        )
      end
    end

    ##
    # Gets the remaining validation attempts for an identifier.
    #
    # @param identifier [String] UUID to check (rate limited per veteran)
    # @return [Integer] Number of attempts remaining (0 if limit exceeded)
    #
    def validation_attempts_remaining(identifier:)
      current = validation_rate_limit_count(identifier:)
      remaining = rate_limit_max_attempts - current
      [remaining, 0].max
    end

    private

    ##
    # Generates a cache key for OTP storage.
    #
    # @param uuid [String] Veteran UUID
    # @return [String] Cache key
    #
    def otp_key(uuid)
      "otp_#{uuid}"
    end

    ##
    # Generates a cache key for veteran metadata storage.
    #
    # @param uuid [String] Veteran UUID
    # @return [String] Cache key
    #
    def veteran_metadata_key(uuid)
      "veteran_metadata_#{uuid}"
    end

    ##
    # Generates a cache key for booking session storage.
    #
    # @param veteran_id [String] Veteran ID (UUID)
    # @return [String] Cache key
    #
    def booking_session_key(veteran_id)
      "booking_session_#{veteran_id}"
    end

    ##
    # Generates a cache key for session storage.
    #
    # @param uuid [String] Veteran UUID
    # @return [String] Cache key
    #
    def session_key(uuid)
      "session_#{uuid}"
    end

    ##
    # Generates a cache key for rate limiting.
    #
    # @param identifier [String] UUID for rate limiting
    # @return [String] Cache key
    #
    def rate_limit_key(identifier)
      "rate_limit_#{identifier.to_s.downcase.strip}"
    end

    ##
    # Generates a cache key for validation rate limiting.
    #
    # @param identifier [String] UUID for rate limiting
    # @return [String] Cache key
    #
    def validation_rate_limit_key(identifier)
      "validation_rate_limit_#{identifier}"
    end

    ##
    # Returns the maximum number of attempts allowed.
    #
    # @return [Integer] Max attempts
    #
    def rate_limit_max_attempts
      @settings.rate_limit_max_attempts.to_i
    end

    ##
    # Returns the rate limit expiry time in seconds.
    #
    # @return [Integer] Expiry duration in seconds
    #
    def rate_limit_expiry
      @settings.rate_limit_expiry.to_i
    end

    ##
    # Wraps Redis operations to catch Redis::BaseError and re-raise as Vass::Errors::RedisError.
    #
    # @yield Block containing Redis operation
    # @return [Object] Result of the block
    # @raise [Vass::Errors::RedisError] if Redis operation fails
    #
    def with_redis_error_handling
      yield
    rescue Redis::BaseError => e
      raise Vass::Errors::RedisError, "Redis operation failed: #{e.message}"
    end

    ##
    # Lazily initializes and returns the token encryptor for OAuth token encryption/decryption.
    #
    # @return [Vass::TokenEncryptor] Token encryptor instance
    #
    def token_encryptor
      @token_encryptor ||= Vass::TokenEncryptor.build
    end
  end
end
