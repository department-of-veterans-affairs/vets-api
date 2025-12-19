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
        expires_in: settings.redis_token_expiry
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
        expires_in: settings.redis_otc_expiry
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
        expires_in: settings.redis_session_expiry
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
    # Generates a cache key for session storage.
    #
    # @param session_token [String] Session token
    # @return [String] Cache key
    #
    def session_key(session_token)
      "session_#{session_token}"
    end
  end
end
