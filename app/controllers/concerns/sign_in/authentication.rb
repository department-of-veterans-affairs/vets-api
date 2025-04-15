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
      @current_user = load_user_object
      validate_request_ip
      @current_user.present?
    rescue Errors::AccessTokenExpiredError => e
      render json: { errors: e }, status: :forbidden
    rescue Errors::StandardError => e
      handle_authenticate_error(e)
    end

    def load_user(skip_expiration_check: false)
      @current_user = load_user_object
      validate_request_ip
      @current_user.present?
    rescue Errors::AccessTokenExpiredError => e
      render json: { errors: e }, status: :forbidden unless skip_expiration_check
    rescue Errors::StandardError
      nil
    end

    def access_token_authenticate(skip_render_error: false, re_raise: false)
      access_token.present?
    rescue Errors::AccessTokenExpiredError => e
      raise if re_raise

      render json: { errors: e }, status: :forbidden unless skip_render_error
    rescue Errors::StandardError => e
      raise if re_raise

      handle_authenticate_error(e) unless skip_render_error
    end

    private

    def access_token
      @access_token ||= authenticate_access_token
    end

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

    def load_user_object
      UserLoader.new(access_token:, request_ip: request.remote_ip).perform
    end

    def handle_authenticate_error(error, access_token_cookie_name: Constants::Auth::ACCESS_TOKEN_COOKIE_NAME)
      context = {
        access_token_authorization_header: scrub_bearer_token,
        access_token_cookie: cookie_access_token(access_token_cookie_name:)
      }.compact

      log_message_to_sentry(error.message, :error, context) if context.present?
      render json: { errors: error }, status: :unauthorized
    end

    def scrub_bearer_token
      bearer_token == 'undefined' ? nil : bearer_token
    end

    def validate_request_ip
      return if @current_user.fingerprint == request.remote_ip

      log_context = { request_ip: request.remote_ip, fingerprint: @current_user.fingerprint }
      Rails.logger.warn('[SignIn][Authentication] fingerprint mismatch', log_context)
      @current_user.fingerprint = request.remote_ip
      @current_user.save
    end
  end
end
