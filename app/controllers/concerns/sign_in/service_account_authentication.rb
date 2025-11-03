# frozen_string_literal: true

require 'sign_in/logger'

module SignIn
  module ServiceAccountAuthentication
    extend ActiveSupport::Concern

    BEARER_PATTERN = /^Bearer /

    protected

    def authenticate_service_account
      @service_account_access_token = authenticate_service_account_access_token
      validate_requested_scope
      @service_account_access_token.present?
    rescue Errors::AccessTokenExpiredError => e
      render json: { errors: e }, status: :forbidden
    rescue Errors::StandardError => e
      handle_authenticate_error(e)
    end

    private

    def authenticate_service_account_access_token
      ServiceAccountAccessTokenJwtDecoder.new(service_account_access_token_jwt: bearer_token).perform
    end

    def bearer_token
      header = request.authorization
      header.gsub(BEARER_PATTERN, '') if header&.match(BEARER_PATTERN)
    end

    def handle_authenticate_error(error)
      Rails.logger.error('[SignIn][ServiceAccountAuthentication] authentication error',
                         access_token_authorization_header: bearer_token,
                         errors: error.message)
      render json: { errors: error }, status: :unauthorized
    end

    def validate_requested_scope
      authorized_scopes = @service_account_access_token.scopes
      return if authorized_scopes.any? { |scope| request.url.include?(scope) }

      raise Errors::InvalidServiceAccountScope.new message: 'Required scope for requested resource not found'
    end
  end
end
