# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class RefreshController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[refresh]
      before_action :validate_refresh_token

      def refresh
        sign_in_logger.info('refresh', session_container.context)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REFRESH_SUCCESS)
        render json: serializer_response, status: :ok
      rescue SignIn::Errors::StandardError => e
        status = e.is_a?(MalformedParamsError) ? :bad_request : :unauthorized
        render_error(e, status)
      end

      private

      def validate_refresh_token
        unless refresh_token
          error = SignIn::Errors::MalformedParamsError.new message: 'Refresh token is not defined'
          render_error(error, :unauthorized)
        end
      end

      def render_error(error, status)
        sign_in_logger.info('refresh error', { errors: error.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REFRESH_FAILURE)
        render json: { errors: error }, status:
      end

      def refresh_token
        params[:refresh_token] || token_cookies[SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME]
      end

      def anti_csrf_token
        params[:anti_csrf_token] || token_cookies[SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME]
      end

      def session_container
        SignIn::SessionRefresher.new(refresh_token: decrypted_refresh_token, anti_csrf_token:).perform
      end

      def decrypted_refresh_token
        SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
      end

      def serializer_response
        SignIn::TokenSerializer.new(session_container:, cookies: token_cookies).perform
      end

      def token_cookies
        @token_cookies ||= defined?(cookies) ? cookies : nil
      end

      def sign_in_logger
        @sign_in_logger = SignIn::Logger.new(prefix: self.class)
      end
    end
  end
end
