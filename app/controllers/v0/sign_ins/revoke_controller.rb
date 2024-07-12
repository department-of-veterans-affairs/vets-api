# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class RevokeController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[revoke revoke_all_sessions]
      before_action :access_token_authenticate, only: :revoke_all_sessions
      before_action :validate_refresh_token, only: %i[revoke]

      def revoke
        refresh_token = decrypted_refresh_token
        anti_csrf_token = params[:anti_csrf_token]
        device_secret = params[:device_secret]

        SignIn::SessionRevoker.new(refresh_token:, anti_csrf_token:, device_secret:).perform

        log_revoke_success
        render status: :ok
      rescue SignIn::Errors::StandardError => e
        log_revoke_failure(e)
        render json: { errors: e }, status: :unauthorized
      end

      def revoke_all_sessions
        validate_session

        SignIn::RevokeSessionsForUser.new(user_account: session.user_account).perform

        log_revoke_all_success
        render status: :ok
      rescue SignIn::Errors::StandardError => e
        log_revoke_all_failure(e)
        render json: { errors: e }, status: :unauthorized
      end

      private

      def validate_refresh_token
        unless params[:refresh_token]
          error = SignIn::Errors::MalformedParamsError.new message: 'Refresh token is not defined'
          log_revoke_failure(error)
          render json: { errors: error }, status: :bad_request
        end
      end

      def validate_session
        raise SignIn::Errors::SessionNotFoundError.new message: 'Session not found' if session.blank?
      end

      def session
        return @session if defined?(@session)
        @session ||= SignIn::OAuthSession.find_by(handle: @access_token.session_handle)
      end

      def decrypted_refresh_token
        encrypted_refresh_token = params[:refresh_token]
        @decrypted_refresh_token ||= SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: ).perform
      end

      def sign_in_logger
        @sign_in_logger = SignIn::Logger.new(prefix: self.class)
      end

      def log_revoke_success
        sign_in_logger.info('revoke', decrypted_refresh_token.to_s)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_SUCCESS)
      end

      def log_revoke_failure(error)
        sign_in_logger.info('revoke error', { errors: error.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_FAILURE)
      end

      def log_revoke_all_success
        sign_in_logger.info('revoke all sessions', @access_token.to_s)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_SUCCESS)
      end

      def log_revoke_all_failure(error)
        sign_in_logger.info('revoke all sessions error', { errors: error.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_FAILURE)
      end
    end
  end
end
