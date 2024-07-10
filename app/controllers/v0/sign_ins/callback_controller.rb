# frozen_string_literal: true

require 'sign_in/logger'

module V0
  module SignIns
    class CallbackController < SignIn::ApplicationController
      skip_before_action :authenticate, only: %i[callback]

      def callback # rubocop:disable Metrics/MethodLength
        code = params[:code].presence
        state = params[:state].presence
        error = params[:error].presence

        validate_callback_params(code, state, error)

        state_payload = SignIn::StatePayloadJwtDecoder.new(state_payload_jwt: state).perform
        SignIn::StatePayloadVerifier.new(state_payload:).perform

        handle_credential_provider_error(error, state_payload&.type) if error
        service_token_response = auth_service(state_payload.type, state_payload.client_id).token(code)

        raise SignIn::Errors::CodeInvalidError.new message: 'Code is not valid' unless service_token_response

        user_info = auth_service(state_payload.type,
                                 state_payload.client_id).user_info(service_token_response[:access_token])
        credential_level = SignIn::CredentialLevelCreator.new(requested_acr: state_payload.acr,
                                                              type: state_payload.type,
                                                              logingov_acr: service_token_response[:logingov_acr],
                                                              user_info:).perform
        if credential_level.can_uplevel_credential?
          render_uplevel_credential(state_payload)
        else
          create_login_code(state_payload, user_info, credential_level)
        end
      rescue SignIn::Errors::StandardError => e
        sign_in_logger.info('callback error', { errors: e.message,
                                                client_id: state_payload&.client_id,
                                                type: state_payload&.type,
                                                acr: state_payload&.acr })
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE)
        handle_pre_login_error(e, state_payload&.client_id)
      rescue => e
        log_message_to_sentry(e.message, :error)
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE)
        handle_pre_login_error(e, state_payload&.client_id)
      end

      private

      def validate_callback_params(code, state, error)
        raise SignIn::Errors::MalformedParamsError.new message: 'Code is not defined' unless code || error
        raise SignIn::Errors::MalformedParamsError.new message: 'State is not defined' unless state
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

      def handle_credential_provider_error(error, type)
        if error == SignIn::Constants::Auth::ACCESS_DENIED
          error_message = 'User Declined to Authorize Client'
          error_code = if type == SignIn::Constants::Auth::LOGINGOV
                         SignIn::Constants::ErrorCode::LOGINGOV_VERIFICATION_DENIED
                       else
                         SignIn::Constants::ErrorCode::IDME_VERIFICATION_DENIED
                       end
          raise SignIn::Errors::AccessDeniedError.new message: error_message, code: error_code
        else
          error_message = 'Unknown Credential Provider Issue'
          error_code = SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE
          raise SignIn::Errors::CredentialProviderError.new message: error_message, code: error_code
        end
      end

      def render_uplevel_credential(state_payload)
        acr_for_type = SignIn::AcrTranslator.new(acr: state_payload.acr, type: state_payload.type,
                                                 uplevel: true).perform
        state = SignIn::StatePayloadJwtEncoder.new(code_challenge: state_payload.code_challenge,
                                                   code_challenge_method: SignIn::Constants::Auth::CODE_CHALLENGE_METHOD,
                                                   acr: state_payload.acr,
                                                   client_config: client_config(state_payload.client_id),
                                                   type: state_payload.type,
                                                   client_state: state_payload.client_state).perform
        render body: auth_service(state_payload.type, state_payload.client_id).render_auth(state:, acr: acr_for_type),
               content_type: 'text/html'
      end

      def create_login_code(state_payload, user_info, credential_level) # rubocop:disable Metrics/MethodLength
        user_attributes = auth_service(state_payload.type,
                                       state_payload.client_id).normalized_attributes(user_info, credential_level)
        verified_icn = SignIn::AttributeValidator.new(user_attributes:).perform
        user_code_map = SignIn::UserCodeMapCreator.new(
          user_attributes:, state_payload:, verified_icn:, request_ip: request.remote_ip
        ).perform

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
        StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS,
                         tags: ["type:#{state_payload.type}",
                                "client_id:#{state_payload.client_id}",
                                "ial:#{credential_level.current_ial}",
                                "acr:#{state_payload.acr}"])
        params_hash = { code: user_code_map.login_code, type: user_code_map.type }
        params_hash.merge!(state: user_code_map.client_state) if user_code_map.client_state.present?

        render body: SignIn::RedirectUrlGenerator.new(redirect_uri: user_code_map.client_config.redirect_uri,
                                                      terms_code: user_code_map.terms_code,
                                                      terms_redirect_uri: user_code_map.client_config.terms_of_use_url,
                                                      params_hash:).perform,
               content_type: 'text/html'
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
