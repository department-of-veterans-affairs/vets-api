# frozen_string_literal: true

module Vass
  ##
  # Redis client for caching OAuth tokens, OTC codes, and session data.
  #
  # Handles:
  # - OAuth access token from Microsoft identity provider (shared across requests)
  # - One-Time Codes (OTC) for veteran verification flow
  # - Session data (EDIPI, veteran_id) after successful OTC verification
  #
  class RedisClient
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
    delegate :redis_token_expiry, :redis_otc_expiry, :redis_session_expiry, to: :@settings

    # ------------ OAuth Token Management ------------

    ##
    # Retrieves the cached OAuth access token.
    #
    # @return [String, nil] Cached OAuth token or nil if not present/expired
    #
    def token
      Rails.cache.read(
        'oauth_token',
        namespace: 'vass-auth-cache'
      )
    end

    ##
    # Saves the OAuth access token to cache with expiration.
    #
    # @param token [String, nil] OAuth token to cache (nil clears the cache)
    # @return [Boolean] true if write succeeds
    #
    def save_token(token:)
      Rails.cache.write(
        'oauth_token',
        token,
        namespace: 'vass-auth-cache',
        expires_in: redis_token_expiry
      )
    end

    # ------------ One-Time Code (OTC) Management ------------

    ##
    # Retrieves a stored OTC by UUID.
    #
    # @param uuid [String] Veteran UUID from email link
    # @return [String, nil] OTC or nil if not found/expired
    #
    def otc(uuid:)
      Rails.cache.read(
        otc_key(uuid),
        namespace: 'vass-otc-cache'
      )
    end

    ##
    # Saves an OTC for a veteran UUID with short expiration.
    #
    # @param uuid [String] Veteran UUID
    # @param code [String] One-time code
    # @return [Boolean] true if write succeeds
    #
    def save_otc(uuid:, code:)
      Rails.cache.write(
        otc_key(uuid),
        code,
        namespace: 'vass-otc-cache',
        expires_in: redis_otc_expiry
      )
    end

    ##
    # Deletes an OTC after successful verification (one-time use).
    #
    # @param uuid [String] Veteran UUID
    # @return [void]
    #
    def delete_otc(uuid:)
      Rails.cache.delete(
        otc_key(uuid),
        namespace: 'vass-otc-cache'
      )
    end

    ##
    # Saves veteran metadata (edipi, veteran_id) keyed by UUID.
    # Used to avoid fetching veteran data again in the show flow.
    #
    # @param uuid [String] Veteran UUID
    # @param edipi [String] Veteran EDIPI
    # @param veteran_id [String] Veteran ID
    # @return [Boolean] true if write succeeds
    #
    def save_veteran_metadata(uuid:, edipi:, veteran_id:)
      metadata = {
        edipi:,
        veteran_id:
      }

      Rails.cache.write(
        veteran_metadata_key(uuid),
        Oj.dump(metadata),
        namespace: 'vass-otc-cache',
        expires_in: redis_otc_expiry
      )
    end

    ##
    # Retrieves veteran metadata by UUID.
    #
    # @param uuid [String] Veteran UUID
    # @return [Hash, nil] Metadata hash with edipi and veteran_id, or nil if not found/expired
    #
    def veteran_metadata(uuid:)
      cached = Rails.cache.read(
        veteran_metadata_key(uuid),
        namespace: 'vass-otc-cache'
      )

      return nil if cached.nil?

      begin
        Oj.load(cached).with_indifferent_access
      rescue Oj::ParseError
        Rails.logger.error('VASS RedisClient failed to parse veteran metadata from cache')
        nil
      end
    end

    # ------------ Session Management ------------

    ##
    # Saves session data after successful OTC verification.
    # Stores EDIPI and veteran_id for use in subsequent VASS API calls.
    #
    # @param session_token [String] Session token (generated after OTC verification)
    # @param edipi [String] Veteran EDIPI (required for VASS API headers)
    # @param veteran_id [String] Veteran ID in VASS system
    # @param uuid [String] Original UUID from email link
    # @return [Boolean] true if write succeeds
    #
    def save_session(session_token:, edipi:, veteran_id:, uuid:)
      session_data = {
        edipi:,
        veteran_id:,
        uuid:
      }

      Rails.cache.write(
        session_key(session_token),
        Oj.dump(session_data),
        namespace: 'vass-session-cache',
        expires_in: redis_session_expiry
      )
    end

    ##
    # Retrieves session data by session token.
    #
    # @param session_token [String] Session token
    # @return [Hash, nil] Session data hash or nil if not found/expired
    #
    def session(session_token:)
      cached = Rails.cache.read(
        session_key(session_token),
        namespace: 'vass-session-cache'
      )

      return nil if cached.nil?

      begin
        Oj.load(cached).with_indifferent_access
      rescue Oj::ParseError
        Rails.logger.error('VASS RedisClient failed to parse session data from cache')
        nil
      end
    end

    ##
    # Retrieves EDIPI from session for use in VASS API headers.
    #
    # @param session_token [String] Session token
    # @return [String, nil] EDIPI or nil if session not found
    #
    def edipi(session_token:)
      session_data = session(session_token:)
      session_data&.dig(:edipi)
    end

    ##
    # Retrieves veteran_id from session for use in VASS API calls.
    #
    # @param session_token [String] Session token
    # @return [String, nil] Veteran ID or nil if session not found
    #
    def veteran_id(session_token:)
      session_data = session(session_token:)
      session_data&.dig(:veteran_id)
    end

    ##
    # Deletes session data (logout/cleanup).
    #
    # @param session_token [String] Session token
    # @return [void]
    #
    def delete_session(session_token:)
      Rails.cache.delete(
        session_key(session_token),
        namespace: 'vass-session-cache'
      )
    end

    # ------------ Rate Limiting ------------

    ##
    # Retrieves the current rate limit count for an identifier.
    #
    # @param identifier [String] UUID to rate limit (rate limited per veteran)
    # @return [Integer] Current attempt count
    #
    def rate_limit_count(identifier:)
      Rails.cache.read(
        rate_limit_key(identifier),
        namespace: 'vass-rate-limit-cache'
      ).to_i
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

      Rails.cache.write(
        rate_limit_key(identifier),
        new_count,
        namespace: 'vass-rate-limit-cache',
        expires_in: rate_limit_expiry
      )

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
      Rails.cache.delete(
        rate_limit_key(identifier),
        namespace: 'vass-rate-limit-cache'
      )
    end

    # ------------ Validation Rate Limiting ------------

    ##
    # Retrieves the current validation rate limit count for an identifier.
    #
    # @param identifier [String] UUID to rate limit (rate limited per veteran)
    # @return [Integer] Current attempt count
    #
    def validation_rate_limit_count(identifier:)
      Rails.cache.read(
        validation_rate_limit_key(identifier),
        namespace: 'vass-rate-limit-cache'
      ).to_i
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

      Rails.cache.write(
        validation_rate_limit_key(identifier),
        new_count,
        namespace: 'vass-rate-limit-cache',
        expires_in: rate_limit_expiry
      )

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
      Rails.cache.delete(
        validation_rate_limit_key(identifier),
        namespace: 'vass-rate-limit-cache'
      )
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
    # Generates a cache key for OTC storage.
    #
    # @param uuid [String] Veteran UUID
    # @return [String] Cache key
    #
    def otc_key(uuid)
      "otc_#{uuid}"
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
    # Generates a cache key for session storage.
    #
    # @param session_token [String] Session token
    # @return [String] Cache key
    #
    def session_key(session_token)
      "session_#{session_token}"
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
  end
end
