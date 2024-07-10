# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class RefreshController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[refresh]

      def refresh
        refresh_token = refresh_token_param.presence
        anti_csrf_token = anti_csrf_token_param.presence

        raise SignIn::Errors::MalformedParamsError.new message: 'Refresh token is not defined' unless refresh_token

        decrypted_refresh_token = SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
        session_container = SignIn::SessionRefresher.new(refresh_token: decrypted_refresh_token,
                                                         anti_csrf_token:).perform
        serializer_response = SignIn::TokenSerializer.new(session_container:,
                                                          cookies: token_cookies).perform

        sign_in_logger.info('refresh', session_container.context)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REFRESH_SUCCESS)

        render json: serializer_response, status: :ok
      rescue SignIn::Errors::MalformedParamsError => e
        sign_in_logger.info('refresh error', { errors: e.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REFRESH_FAILURE)
        render json: { errors: e }, status: :bad_request
      rescue SignIn::Errors::StandardError => e
        sign_in_logger.info('refresh error', { errors: e.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REFRESH_FAILURE)
        render json: { errors: e }, status: :unauthorized
      end

      private

      def refresh_token_param
        params[:refresh_token] || token_cookies[SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME]
      end

      def anti_csrf_token_param
        params[:anti_csrf_token] || token_cookies[SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME]
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
