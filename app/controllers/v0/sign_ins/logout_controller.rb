# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class LogoutController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[logout logingov_logout_proxy]

      def logout # rubocop:disable Metrics/MethodLength
        client_id = params[:client_id].presence
        anti_csrf_token = anti_csrf_token_param.presence

        if client_config(client_id).blank?
          raise SignIn::Errors::MalformedParamsError.new message: 'Client id is not valid'
        end

        unless access_token_authenticate(skip_error_handling: true)
          raise SignIn::Errors::LogoutAuthorizationError.new message: 'Unable to authorize access token'
        end

        session = SignIn::OAuthSession.find_by(handle: @access_token.session_handle)
        raise SignIn::Errors::SessionNotFoundError.new message: 'Session not found' if session.blank?

        credential_type = session.user_verification.credential_type

        SignIn::SessionRevoker.new(access_token: @access_token, anti_csrf_token:).perform
        delete_cookies if token_cookies

        sign_in_logger.info('logout', @access_token.to_s)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_SUCCESS)

        logout_redirect = SignIn::LogoutRedirectGenerator.new(credential_type:,
                                                              client_config: client_config(client_id)).perform
        logout_redirect ? redirect_to(logout_redirect) : render(status: :ok)
      rescue SignIn::Errors::LogoutAuthorizationError,
            SignIn::Errors::SessionNotAuthorizedError,
            SignIn::Errors::SessionNotFoundError => e
        sign_in_logger.info('logout error', { errors: e.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE)
        logout_redirect = SignIn::LogoutRedirectGenerator.new(client_config: client_config(client_id)).perform

        logout_redirect ? redirect_to(logout_redirect) : render(status: :ok)
      rescue => e
        sign_in_logger.info('logout error', { errors: e.message })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE)

        render json: { errors: e }, status: :bad_request
      end

      def logingov_logout_proxy
        state = params[:state].presence

        raise SignIn::Errors::MalformedParamsError.new message: 'State is not defined' unless state

        render body: auth_service(SignIn::Constants::Auth::LOGINGOV).render_logout_redirect(state),
              content_type: 'text/html'
      rescue => e
        sign_in_logger.info('logingov_logout_proxy error', { errors: e.message })

        render json: { errors: e }, status: :bad_request
      end

      private

      def anti_csrf_token_param
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

      def auth_service(type, client_id = nil)
        SignIn::AuthenticationServiceRetriever.new(type:, client_config: client_config(client_id)).perform
      end

      def client_config(client_id)
        @client_config ||= {}
        @client_config[client_id] ||= SignIn::ClientConfig.find_by(client_id:)
      end

      def sign_in_logger
        @sign_in_logger = SignIn::Logger.new(prefix: self.class)
      end
    end
  end
end
