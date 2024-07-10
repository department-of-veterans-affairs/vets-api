# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class RevokeController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[revoke revoke_all_sessions]
      before_action :access_token_authenticate, only: :revoke_all_sessions

      def revoke
        refresh_token = params[:refresh_token].presence
        anti_csrf_token = params[:anti_csrf_token].presence
        device_secret = params[:device_secret].presence

        raise SignIn::Errors::MalformedParamsError.new message: 'Refresh token is not defined' unless refresh_token

        decrypted_refresh_token = SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
        SignIn::SessionRevoker.new(refresh_token: decrypted_refresh_token, anti_csrf_token:, device_secret:).perform

        sign_in_logger.info('revoke', decrypted_refresh_token.to_s)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_SUCCESS)

        render status: :ok
      rescue SignIn::Errors::MalformedParamsError => e
        sign_in_logger.info('revoke error', { errors: e.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_FAILURE)

        render json: { errors: e }, status: :bad_request
      rescue SignIn::Errors::StandardError => e
        sign_in_logger.info('revoke error', { errors: e.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_FAILURE)

        render json: { errors: e }, status: :unauthorized
      end

      def revoke_all_sessions
        session = SignIn::OAuthSession.find_by(handle: @access_token.session_handle)
        raise SignIn::Errors::SessionNotFoundError.new message: 'Session not found' if session.blank?

        SignIn::RevokeSessionsForUser.new(user_account: session.user_account).perform

        sign_in_logger.info('revoke all sessions', @access_token.to_s)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_SUCCESS)

        render status: :ok
      rescue SignIn::Errors::StandardError => e
        sign_in_logger.info('revoke all sessions error', { errors: e.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_FAILURE)
        render json: { errors: e }, status: :unauthorized
      end

      private

      def sign_in_logger
        @sign_in_logger = SignIn::Logger.new(prefix: self.class)
      end
    end
  end
end
