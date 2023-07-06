# frozen_string_literal: true

require 'sign_in/logger'

module SignIn
  module Authentication
    extend ActiveSupport::Concern

    BEARER_PATTERN = /^Bearer /

    included do
      before_action :authenticate
    end

    protected

    def authenticate
      @access_token = authenticate_access_token
      @current_user = load_user_object
      validate_request_ip
      @current_user.present?
    rescue Errors::AccessTokenExpiredError => e
      render json: { errors: e }, status: :forbidden
    rescue Errors::StandardError => e
      handle_authenticate_error(e)
    end

    def load_user(skip_expiration_check: false)
      @access_token = authenticate_access_token
      @current_user = load_user_object
      validate_request_ip
      @current_user.present?
    rescue Errors::AccessTokenExpiredError => e
      render json: { errors: e }, status: :forbidden unless skip_expiration_check
    rescue Errors::StandardError
      nil
    end

    def authenticate_service_account
      @service_account_access_token = authenticate_service_account_access_token
      validate_requested_scope
      @service_account_access_token.present?
    rescue Errors::AccessTokenExpiredError => e
      render json: { errors: e }, status: :forbidden
    rescue Errors::StandardError => e
      handle_authenticate_error(e, access_token_cookie_name: Constants::Auth::SERVICE_ACCOUNT_ACCESS_TOKEN_COOKIE_NAME)
    end

    private

    def bearer_token
      header = request.authorization
      header.gsub(BEARER_PATTERN, '') if header&.match(BEARER_PATTERN)
    end

    def cookie_access_token(access_token_cookie_name: Constants::Auth::ACCESS_TOKEN_COOKIE_NAME)
      return unless defined?(cookies)

      cookies[access_token_cookie_name]
    end

    def authenticate_access_token(with_validation: true)
      access_token_jwt = bearer_token || cookie_access_token
      AccessTokenJwtDecoder.new(access_token_jwt:).perform(with_validation:)
    end

    def authenticate_service_account_access_token
      access_token_cookie_name = Constants::Auth::SERVICE_ACCOUNT_ACCESS_TOKEN_COOKIE_NAME
      service_account_access_token_jwt = bearer_token || cookie_access_token(access_token_cookie_name:)
      ServiceAccountAccessTokenJwtDecoder.new(service_account_access_token_jwt:).perform
    end

    def load_user_object
      UserLoader.new(access_token: @access_token, request_ip: request.remote_ip).perform
    end

    def handle_authenticate_error(error, access_token_cookie_name: Constants::Auth::ACCESS_TOKEN_COOKIE_NAME)
      context = {
        access_token_authorization_header: bearer_token,
        access_token_cookie: cookie_access_token(access_token_cookie_name:)
      }.compact

      log_message_to_sentry(error.message, :error, context)
      render json: { errors: error }, status: :unauthorized
    end

    def validate_request_ip
      return if @current_user.fingerprint == request.remote_ip

      log_context = { request_ip: request.remote_ip, fingerprint: @current_user.fingerprint }
      Rails.logger.warn('[SignIn][Authentication] fingerprint mismatch', log_context)
      @current_user.fingerprint = request.remote_ip
      @current_user.save
    end

    def validate_requested_scope
      authorized_scopes = @service_account_access_token.scopes
      return if authorized_scopes.include?(request.url)

      raise Errors::InvalidServiceAccountScope.new message: 'Required scope for requested resource not found'
    end
  end
end
