# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class LogoutController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[logout logingov_logout_proxy]
      before_action :validate_client, only: %i[logout]
      before_action :validate_state, only: %i[logingov_logout_proxy]
      before_action :authorize_access_token, only: %i[logout]

      def logout
        validate_session

        SignIn::SessionRevoker.new(access_token: @access_token, anti_csrf_token:).perform
        delete_cookies if token_cookies

        log_logout_success
        logout_redirect = logout_redirect_url(credential_type)
        render_logout_redirect(logout_redirect)
      rescue SignIn::Errors::SessionNotAuthorizedError, SignIn::Errors::SessionNotFoundError => e
        log_logout_failure(e)
        render_logout_redirect(logout_redirect_url)
      rescue => e
        log_logout_failure(e)
        render json: { errors: e }, status: :bad_request
      end

      def logingov_logout_proxy
        render body: logout_proxy_redirect_url, content_type: 'text/html'
      rescue => e
        sign_in_logger.info('logingov_logout_proxy error', { errors: e.message })

        render json: { errors: e }, status: :bad_request
      end

      private

      def validate_client
        if client_config.blank?
          error = SignIn::Errors::MalformedParamsError.new message: 'Client id is not valid'
          log_logout_failure(error)

          render json: { errors: error }, status: :bad_request
        end
      end

      def validate_state
        unless params[:state]
          error = SignIn::Errors::MalformedParamsError.new message: 'State is not defined'
          sign_in_logger.info('logingov_logout_proxy error', { errors: error.message })
          render json: { errors: error }, status: :bad_request
        end
      end

      def validate_session
        raise SignIn::Errors::SessionNotFoundError.new message: 'Session not found' if session.blank?
      end

      def authorize_access_token
        unless access_token_authenticate(skip_error_handling: true)
          error = SignIn::Errors::LogoutAuthorizationError.new message: 'Unable to authorize access token'
          log_logout_failure(error)
          render_logout_redirect(logout_redirect_url)
        end
      end

      def render_logout_redirect(url)
        url ? redirect_to(url) : render(status: :ok)
      end

      def logout_redirect_url(credential_type = nil)
        SignIn::LogoutRedirectGenerator.new(credential_type:, client_config:).perform
      end

      def logout_proxy_redirect_url
        auth_service(SignIn::Constants::Auth::LOGINGOV).render_logout_redirect(params[:state])
      end

      def session
        return @session if defined?(@session)

        @session ||= SignIn::OAuthSession.find_by(handle: @access_token.session_handle)
      end

      def credential_type
        @credential_type ||= session.user_verification.credential_type
      end

      def anti_csrf_token
        params[:anti_csrf_token] || token_cookies[SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME]
      end

      def token_cookies
        @token_cookies ||= defined?(cookies) ? cookies : nil
      end

      def delete_cookies
        cookies.delete(SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME, domain: :all)
        cookies.delete(SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME)
        cookies.delete(SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME)
        cookies.delete(SignIn::Constants::Auth::INFO_COOKIE_NAME, domain: Settings.sign_in.info_cookie_domain)
      end

      def auth_service(type)
        SignIn::AuthenticationServiceRetriever.new(type:, client_config:).perform
      end

      def client_config
        client_id = params[:client_id]
        @client_config ||= {}
        @client_config[client_id] ||= SignIn::ClientConfig.find_by(client_id:)
      end

      def sign_in_logger
        @sign_in_logger = SignIn::Logger.new(prefix: self.class)
      end

      def log_logout_success
        sign_in_logger.info('logout', @access_token.to_s)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_SUCCESS)
      end

      def log_logout_failure(error)
        sign_in_logger.info('logout error', { errors: error.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE)
      end
    end
  end
end
