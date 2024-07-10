# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class AuthorizationController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[authorize]

      def authorize # rubocop:disable Metrics/MethodLength
        type = params[:type].presence
        client_state = params[:state].presence
        code_challenge = params[:code_challenge].presence
        code_challenge_method = params[:code_challenge_method].presence
        client_id = params[:client_id].presence
        acr = params[:acr].presence
        operation = params[:operation].presence || SignIn::Constants::Auth::AUTHORIZE
        scope = params[:scope].presence

        validate_authorize_params(type, client_id, acr, operation)

        delete_cookies if token_cookies

        acr_for_type = SignIn::AcrTranslator.new(acr:, type:).perform
        state = SignIn::StatePayloadJwtEncoder.new(code_challenge:,
                                                  code_challenge_method:,
                                                  acr:,
                                                  client_config: client_config(client_id),
                                                  type:,
                                                  client_state:,
                                                  scope:).perform
        context = { type:, client_id:, acr:, operation: }

        sign_in_logger.info('authorize', context)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_SUCCESS,
                        tags: ["type:#{type}", "client_id:#{client_id}", "acr:#{acr}", "operation:#{operation}"])

        render body: auth_service(type, client_id).render_auth(state:, acr: acr_for_type, operation:),
              content_type: 'text/html'
      rescue SignIn::Errors::StandardError => e
        sign_in_logger.info('authorize error', { errors: e.message, client_id:, type:, acr: })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE)
        handle_pre_login_error(e, client_id)
      rescue => e
        log_message_to_sentry(e.message, :error)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE)
        handle_pre_login_error(e, client_id)
      end

      private

      def validate_authorize_params(type, client_id, acr, operation)
        if client_config(client_id).blank?
          raise SignIn::Errors::MalformedParamsError.new message: 'Client id is not valid'
        end
        unless client_config(client_id).valid_credential_service_provider?(type)
          raise SignIn::Errors::MalformedParamsError.new message: 'Type is not valid'
        end
        unless SignIn::Constants::Auth::OPERATION_TYPES.include?(operation)
          raise SignIn::Errors::MalformedParamsError.new message: 'Operation is not valid'
        end
        unless client_config(client_id).valid_service_level?(acr)
          raise SignIn::Errors::MalformedParamsError.new message: 'ACR is not valid'
        end
      end

      def handle_pre_login_error(error, client_id)
        if cookie_authentication?(client_id)
          error_code = error.try(:code) || SignIn::Constants::ErrorCode::INVALID_REQUEST
          params_hash = { auth: 'fail', code: error_code, request_id: request.request_id }
          render body: SignIn::RedirectUrlGenerator.new(redirect_uri: client_config(client_id).redirect_uri,
                                                        params_hash:).perform,
                content_type: 'text/html'
        else
          render json: { errors: error }, status: :bad_request
        end
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

      def cookie_authentication?(client_id)
        client_config(client_id)&.cookie_auth?
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
