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

    included do
      attr_reader :current_veteran_id
    end

    ##
    # Authenticates JWT from Authorization header.
    #
    # Sets @current_veteran_id on success.
    # Renders error response on failure.
    #
    def authenticate_jwt
      token = extract_token_from_header
      unless token
        log_auth_failure('missing_token')
        render_unauthorized('Missing authentication token')
        return
      end

      payload = decode_jwt(token)
      @current_veteran_id = payload['sub']

      unless @current_veteran_id
        log_auth_failure('missing_veteran_id')
        render_unauthorized('Invalid or malformed token')
      end
    rescue JWT::ExpiredSignature
      log_auth_failure('expired_token')
      render_unauthorized('Token has expired')
    rescue JWT::DecodeError => e
      log_auth_failure('invalid_token', error_class: e.class.name)
      render_unauthorized('Invalid or malformed token')
    end

    private

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

    ##
    # Renders unauthorized error response.
    #
    # @param detail [String] Error detail message
    #
    def render_unauthorized(detail)
      render json: {
        errors: [
          {
            code: 'unauthorized',
            detail:
          }
        ]
      }, status: :unauthorized
    end
  end
end
