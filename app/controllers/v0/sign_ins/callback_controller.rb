# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class CallbackController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[callback]
      before_action :validate_callback_params
      before_action :validate_jwt

      def callback
        SignIn::StatePayloadVerifier.new(state_payload:).perform

        raise_access_denied_error if access_denied?
        raise_credential_provider_error if params[:error]
        raise_code_invalid_error unless service_token_response

        render body: success_response_body, content_type: 'text/html'
      rescue SignIn::Errors::StandardError => e
        log_callback_failure(e, state_payload)
        render_pre_login_error(e)
      rescue => e
        log_message_to_sentry(e.message, :error)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE)
        render_pre_login_error(e)
      end

      private

      def validate_callback_params
        unless params[:code] || params[:error]
          render_invalid_params('Code is not defined')
        end
        unless params[:state]
          render_invalid_params('State is not defined')
        end
      end

      def validate_jwt
        state_payload
      rescue SignIn::Errors::StandardError => error
        log_callback_failure(error)
        render json: { errors: error }, status: :bad_request
      end

      def error_redirect_url(error)
        error_code = error.try(:code) || SignIn::Constants::ErrorCode::INVALID_REQUEST
        params_hash = { auth: 'fail', code: error_code, request_id: request.request_id }
        SignIn::RedirectUrlGenerator.new(redirect_uri: client_config.redirect_uri, params_hash:).perform
      end

      def access_denied?
        params[:error] == SignIn::Constants::Auth::ACCESS_DENIED
      end

      def raise_access_denied_error
        error_message = 'User Declined to Authorize Client'
        raise SignIn::Errors::AccessDeniedError.new message: error_message, code: verification_error_code
      end

      def verification_error_code
        if state_payload.type == SignIn::Constants::Auth::LOGINGOV
          SignIn::Constants::ErrorCode::LOGINGOV_VERIFICATION_DENIED
        else
          SignIn::Constants::ErrorCode::IDME_VERIFICATION_DENIED
        end
      end

      def raise_credential_provider_error
        unless access_denied?
          error_message = 'Unknown Credential Provider Issue'
          error_code = SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE
          raise SignIn::Errors::CredentialProviderError.new message: error_message, code: error_code
        end
      end

      def raise_code_invalid_error
        raise SignIn::Errors::CodeInvalidError.new message: 'Code is not valid'
      end

      def render_invalid_params(message)
        error = SignIn::Errors::MalformedParamsError.new(message: message)
        log_callback_failure(error)
        render json: { errors: error }, status: :bad_request
      end

      def render_pre_login_error(error)
        if cookie_authentication?
          render body: error_redirect_url(error), content_type: 'text/html'
        else
          render json: { errors: error }, status: :bad_request
        end
      end

      def success_response_body
        if credential_level.can_uplevel_credential?
          auth_service.render_auth(state: response_state, acr: acr_for_type)
        else
          log_callback_success
          login_code_redirect_url
        end
      end

      def acr_for_type
        SignIn::AcrTranslator.new(acr: state_payload.acr, type: state_payload.type, uplevel: true).perform
      end

      def response_state
        SignIn::StatePayloadJwtEncoder.new(
          code_challenge: state_payload.code_challenge,
          code_challenge_method: SignIn::Constants::Auth::CODE_CHALLENGE_METHOD,
          acr: state_payload.acr,
          client_config: client_config,
          type: state_payload.type,
          client_state: state_payload.client_state
        ).perform
      end

      def log_callback_success
        context = {
          type: state_payload.type,
          client_id: state_payload.client_id,
          ial: credential_level.current_ial,
          acr: state_payload.acr,
          icn: verified_icn,
          uuid: user_info.sub,
          authentication_time: Time.zone.now.to_i - state_payload.created_at
        }
        sign_in_logger.info('callback', context)

        tags = [
          "type:#{state_payload.type}",
          "client_id:#{state_payload.client_id}",
          "ial:#{credential_level.current_ial}",
          "acr:#{state_payload.acr}"
        ]
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS, tags:)
      end

      def log_callback_failure(error, payload = nil)
        context = {
          errors: error.message,
          client_id: payload&.client_id,
          type: payload&.type,
          acr: payload&.acr
        }
        sign_in_logger.info('callback error', context)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE)
      end

      def login_code_redirect_url
        SignIn::RedirectUrlGenerator.new(
          redirect_uri: user_code_map.client_config.redirect_uri,
          terms_code: user_code_map.terms_code,
          terms_redirect_uri:  user_code_map.client_config.terms_of_use_url,
          params_hash: login_code_redirect_params
        ).perform
      end

      def login_code_redirect_params
        params_hash = { code: user_code_map.login_code, type: user_code_map.type }
        params_hash.merge!(state: user_code_map.client_state) if user_code_map.client_state.present?
      end

      def user_code_map
        @user_code_map ||= SignIn::UserCodeMapCreator.new(
          user_attributes:, state_payload:, verified_icn:, request_ip: request.remote_ip
        ).perform
      end

      def user_attributes
        @user_attributes ||= auth_service.normalized_attributes(user_info, credential_level)
      end

      def verified_icn
        @verified_icn ||= SignIn::AttributeValidator.new(user_attributes:).perform
      end

      def state_payload
        @state_payload ||= SignIn::StatePayloadJwtDecoder.new(state_payload_jwt: params[:state]).perform
      end

      def auth_service
        type = state_payload.type
        SignIn::AuthenticationServiceRetriever.new(type:, client_config:).perform
      end

      def service_token_response
        auth_service.token(params[:code])
      end

      def user_info
        auth_service.user_info(service_token_response[:access_token])
      end

      def credential_level
        SignIn::CredentialLevelCreator.new(
          requested_acr: state_payload.acr,
          type: state_payload.type,
          logingov_acr: service_token_response[:logingov_acr],
          user_info:
        ).perform
      end

      def cookie_authentication?
        client_config&.cookie_auth?
      end

      def client_config
        client_id = state_payload.client_id
        @client_config ||= {}
        @client_config[client_id] ||= SignIn::ClientConfig.find_by(client_id: )
      end

      def sign_in_logger
        @sign_in_logger = SignIn::Logger.new(prefix: self.class)
      end
    end
  end
end
