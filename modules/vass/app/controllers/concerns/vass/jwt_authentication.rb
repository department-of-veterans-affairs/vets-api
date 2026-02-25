# frozen_string_literal: true

module Vass
  ##
  # JWT Authentication concern for VASS controllers.
  #
  # Provides JWT token validation for authenticated endpoints.
  # Expects JWT in Authorization header: "Bearer <token>"
  #
  # The JWT payload must contain:
  #   - sub: veteran_id (UUID)
  #   - exp: expiration timestamp
  #   - iat: issued at timestamp
  #   - jti: unique JWT ID
  #
  # @example Usage in controller
  #   class Vass::V0::AppointmentsController < Vass::ApplicationController
  #     include Vass::JwtAuthentication
  #     before_action :authenticate_jwt
  #
  #     def index
  #       # @current_veteran_id is available here
  #     end
  #   end
  #
  module JwtAuthentication
    extend ActiveSupport::Concern
    include Vass::MetricsConstants

    included do
      attr_reader :current_veteran_id, :current_jti
    end

    ##
    # Authenticates JWT from Authorization header.
    #
    # Sets @current_veteran_id and @current_jti on success.
    # Renders error response on failure.
    # Checks session exists to support token revocation.
    #
    def authenticate_jwt
      token = extract_token_from_header
      return handle_missing_token unless token

      payload = decode_jwt(token)
      @current_veteran_id = payload['sub']
      @current_jti = payload['jti']

      return handle_missing_veteran_id unless @current_veteran_id

      handle_revoked_token unless session_valid?
    rescue JWT::ExpiredSignature
      handle_expired_token
    rescue JWT::DecodeError => e
      handle_invalid_token(e)
    end

    ##
    # Returns audit metadata hash for including jti in log events.
    # Use this when logging authenticated actions to create an audit trail.
    #
    # @return [Hash] Hash containing jti if present, empty hash otherwise
    #
    def audit_metadata
      return {} unless current_jti

      { jti: current_jti }
    end

    private

    def handle_missing_token
      log_auth_failure('missing_token')
      raise Vass::Errors::AuthenticationError, Vass::Errors::AuthenticationError::MISSING_TOKEN
    end

    def handle_missing_veteran_id
      log_auth_failure('missing_veteran_id')
      raise Vass::Errors::AuthenticationError, Vass::Errors::AuthenticationError::INVALID_TOKEN
    end

    def handle_revoked_token
      log_auth_failure('revoked_token')
      raise Vass::Errors::AuthenticationError, Vass::Errors::AuthenticationError::REVOKED_TOKEN
    end

    def handle_expired_token
      log_auth_failure('expired_token')
      track_session_timeout
      raise Vass::Errors::AuthenticationError, Vass::Errors::AuthenticationError::EXPIRED_TOKEN
    end

    ##
    # Tracks session timeout event with StatsD metric and detailed logging.
    #
    def track_session_timeout
      StatsD.increment(SESSION_JWT_EXPIRED, tags: [SERVICE_TAG])
      log_vass_event(
        action: 'session_timeout',
        level: :warn,
        component: 'jwt_authentication',
        failure_type: 'jwt_expired'
      )
    end

    def handle_invalid_token(exception)
      log_auth_failure('invalid_token', error_class: exception.class.name)
      raise Vass::Errors::AuthenticationError, Vass::Errors::AuthenticationError::INVALID_TOKEN
    end

    ##
    # Checks if the current token is still the active session token.
    # Returns false if session doesn't exist or a newer token has been issued.
    #
    # @return [Boolean] true if token is the active session token
    #
    def session_valid?
      return false unless @current_veteran_id && @current_jti

      redis_client.session_valid_for_jti?(uuid: @current_veteran_id, jti: @current_jti)
    end

    ##
    # Returns Redis client instance.
    #
    # @return [Vass::RedisClient] Redis client
    #
    def redis_client
      @redis_client ||= Vass::RedisClient.build
    end

    ##
    # Extracts JWT token from Authorization header.
    #
    # @return [String, nil] JWT token or nil if not found
    #
    def extract_token_from_header
      auth_header = request.headers['Authorization']
      return nil unless auth_header

      # Expected format: "Bearer <token>"
      # Using \S+ (non-whitespace) instead of .+ to prevent ReDoS vulnerability
      match = auth_header.match(/^Bearer\s+(\S+)$/i)
      match&.[](1)
    end

    ##
    # Decodes and validates JWT token.
    #
    # @param token [String] JWT token
    # @return [Hash] Decoded payload
    # @raise [JWT::DecodeError] if token is invalid
    # @raise [JWT::ExpiredSignature] if token is expired
    #
    def decode_jwt(token)
      JWT.decode(token, jwt_secret, true, algorithm: 'HS256')[0]
    end

    ##
    # Decodes JWT without expiration verification.
    # Used for token revocation - users should be able to logout even with expired tokens.
    #
    # @param token [String] JWT token
    # @return [Hash, nil] Decoded payload or nil if invalid signature/format
    #
    def decode_jwt_for_revocation(token)
      JWT.decode(token, jwt_secret, true, { algorithm: 'HS256', verify_expiration: false })[0]
    rescue JWT::DecodeError => e
      log_auth_failure('revocation_decode_error', error_class: e.class.name)
      nil
    end

    ##
    # Returns JWT secret from VASS configuration.
    #
    # @return [String] JWT secret key
    #
    def jwt_secret
      Settings.vass.jwt_secret
    end

    ##
    # Logs JWT authentication failures without PHI.
    #
    # @param reason [String] Failure reason
    # @param error_class [String, nil] Optional error class name
    #
    def log_auth_failure(reason, error_class: nil)
      metadata = { component: 'jwt_authentication', reason: }
      metadata[:error_class] = error_class if error_class

      log_vass_event(action: 'auth_failure', level: :warn, **metadata)
    end
  end
end
