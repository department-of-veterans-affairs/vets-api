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
        render_unauthorized('Missing authentication token')
        return
      end

      payload = decode_jwt(token)
      @current_veteran_id = payload['sub']

      render_unauthorized('Invalid token: missing veteran_id') unless @current_veteran_id
    rescue JWT::ExpiredSignature
      render_unauthorized('Token has expired')
    rescue JWT::DecodeError => e
      render_unauthorized("Invalid token: #{e.message}")
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
    # Returns JWT secret from Rails configuration.
    #
    # @return [String] JWT secret key
    #
    def jwt_secret
      Rails.application.secret_key_base
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
