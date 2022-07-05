# frozen_string_literal: true

require 'sign_in/logingov/service'
require 'sign_in/idme/service'
require 'sign_in/logger'

module V0
  class SignInController < SignIn::ApplicationController
    skip_before_action :authenticate, only: %i[authorize callback token refresh revoke]

    def authorize
      type = params[:type]
      client_state = params[:state]
      code_challenge = params[:code_challenge]
      code_challenge_method = params[:code_challenge_method]
      client_id = params[:client_id]
      acr = params[:acr]

      validate_authorize_params(type, client_id, code_challenge, code_challenge_method, acr)

      acr_for_type = SignIn::AcrTranslator.new(acr: acr, type: type).perform
      state = SignIn::StatePayloadJwtEncoder.new(code_challenge: code_challenge,
                                                 code_challenge_method: code_challenge_method,
                                                 acr: acr,
                                                 client_id: client_id,
                                                 type: type,
                                                 client_state: client_state).perform
      log_successful_authorize(type, client_id, acr)

      render body: auth_service(type).render_auth(state: state, acr: acr_for_type), content_type: 'text/html'
    rescue SignIn::Errors::StandardError => e
      handle_authorize_error(e, type, client_id, acr)
    end

    def callback
      code = params[:code]
      state = params[:state]

      validate_callback_params(code, state)

      state_payload = SignIn::StatePayloadJwtDecoder.new(state_payload_jwt: state).perform
      service_token_response = auth_service(state_payload.type).token(code)
      raise SignIn::Errors::CodeInvalidError, 'Code is not valid' unless service_token_response

      user_info = auth_service(state_payload.type).user_info(service_token_response[:access_token])
      credential_level = SignIn::CredentialLevelCreator.new(requested_acr: state_payload.acr,
                                                            type: state_payload.type,
                                                            id_token: service_token_response[:id_token],
                                                            user_info: user_info).perform
      if credential_level.can_uplevel_credential?
        render_uplevel_credential(state_payload, state)
      else
        create_login_code(state_payload, user_info, credential_level, service_token_response)
      end
    rescue SignIn::Errors::StandardError => e
      handle_callback_error(e, state_payload, state, code)
    end

    def token
      code = params[:code]
      code_verifier = params[:code_verifier]
      grant_type = params[:grant_type]

      validate_token_params(code, code_verifier, grant_type)
      validated_credential = SignIn::CodeValidator.new(code: code,
                                                       code_verifier: code_verifier,
                                                       grant_type: grant_type).perform
      session_container = SignIn::SessionCreator.new(validated_credential: validated_credential).perform
      log_successful_token(session_container, code)

      serializer_response = SignIn::TokenSerializer.new(session_container: session_container,
                                                        cookies: token_cookies).perform
      render json: serializer_response, status: :ok
    rescue SignIn::Errors::StandardError => e
      handle_token_error(e)
    end

    def refresh
      refresh_token = params[:refresh_token] || token_cookies[SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME]
      anti_csrf_token = params[:anti_csrf_token] || token_cookies[SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME]

      raise SignIn::Errors::MalformedParamsError, 'Refresh token is not defined' unless refresh_token

      decrypted_refresh_token = SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
      session_container = SignIn::SessionRefresher.new(refresh_token: decrypted_refresh_token,
                                                       anti_csrf_token: anti_csrf_token).perform
      log_successful_refresh(session_container.refresh_token)

      serializer_response = SignIn::TokenSerializer.new(session_container: session_container,
                                                        cookies: token_cookies).perform
      render json: serializer_response, status: :ok
    rescue SignIn::Errors::MalformedParamsError => e
      handle_refresh_error(e, status: :bad_request)
    rescue SignIn::Errors::StandardError => e
      handle_refresh_error(e)
    end

    def revoke
      refresh_token = params[:refresh_token]
      anti_csrf_token = params[:anti_csrf_token]

      raise SignIn::Errors::MalformedParamsError, 'Refresh token is not defined' unless refresh_token

      decrypted_refresh_token = SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
      SignIn::SessionRevoker.new(refresh_token: decrypted_refresh_token,
                                 anti_csrf_token: anti_csrf_token,
                                 access_token: nil).perform
      log_successful_revoke(decrypted_refresh_token)

      render status: :ok
    rescue SignIn::Errors::MalformedParamsError => e
      handle_revoke_error(e, status: :bad_request)
    rescue SignIn::Errors::StandardError => e
      handle_revoke_error(e)
    end

    def revoke_all_sessions
      SignIn::RevokeSessionsForUser.new(user_uuid: @current_user.uuid).perform
      log_successful_revoke_all_sessions(@access_token)

      render status: :ok
    rescue SignIn::Errors::StandardError => e
      handle_revoke_all_sessions_error(e)
    end

    def logout
      anti_csrf_token = params[:anti_csrf_token] || token_cookies[SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME]

      SignIn::SessionRevoker.new(access_token: @access_token,
                                 refresh_token: nil,
                                 anti_csrf_token: anti_csrf_token).perform
      delete_cookies if token_cookies
      log_successful_logout(@access_token)

      credential_info = SignIn::CredentialInfo.find(@current_user.logingov_uuid)
      if credential_info
        redirect_to auth_service(credential_info.credential_type).render_logout(id_token: credential_info.id_token)
      else
        render status: :ok
      end
    rescue SignIn::Errors::StandardError => e
      handle_logout_error(e)
    end

    def introspect
      sign_in_logger.access_token_log('introspect', @access_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_INTROSPECT_SUCCESS)

      render json: @current_user, serializer: SignIn::IntrospectSerializer, status: :ok
    rescue SignIn::Errors::StandardError => e
      handle_introspect_error(e)
    end

    private

    def validate_authorize_params(type, client_id, code_challenge, code_challenge_method, acr)
      unless SignIn::Constants::ClientConfig::CLIENT_IDS.include?(client_id)
        raise SignIn::Errors::MalformedParamsError, 'Client id is not valid'
      end
      unless SignIn::Constants::Auth::REDIRECT_URLS.include?(type)
        raise SignIn::Errors::AuthorizeInvalidType, 'Type is not valid'
      end
      unless SignIn::Constants::Auth::ACR_VALUES.include?(acr)
        raise SignIn::Errors::MalformedParamsError, 'ACR is not valid'
      end
      raise SignIn::Errors::MalformedParamsError, 'Code Challenge is not defined' unless code_challenge
      raise SignIn::Errors::MalformedParamsError, 'Code Challenge Method is not defined' unless code_challenge_method
    end

    def validate_callback_params(code, state)
      raise SignIn::Errors::MalformedParamsError, 'Code is not defined' unless code
      raise SignIn::Errors::MalformedParamsError, 'State is not defined' unless state
    end

    def validate_token_params(code, code_verifier, grant_type)
      raise SignIn::Errors::MalformedParamsError, 'Code is not defined' unless code
      raise SignIn::Errors::MalformedParamsError, 'Code Verifier is not defined' unless code_verifier
      raise SignIn::Errors::MalformedParamsError, 'Grant Type is not defined' unless grant_type
    end

    def log_successful_authorize(type, client_id, acr)
      attributes = {
        type: type,
        client_id: client_id,
        acr: acr
      }
      sign_in_logger.info('authorize', attributes)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_SUCCESS, tags: ["context:#{type}"])
    end

    def handle_authorize_error(error, type, client_id, acr)
      context = {
        type: type,
        client_id: client_id,
        acr: acr
      }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_FAILURE, tags: ["context:#{type}"])
      render json: { errors: error }, status: :bad_request
    end

    def log_successful_callback(type, client_id)
      attributes = {
        type: type,
        client_id: client_id
      }
      sign_in_logger.info('callback', attributes)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS, tags: ["context:#{type}"])
    end

    def log_successful_token(session_container, code)
      sign_in_logger.refresh_token_log('token',
                                       session_container.refresh_token,
                                       { code: code })
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS)
    end

    def log_successful_refresh(refresh_token)
      sign_in_logger.refresh_token_log('refresh', refresh_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REFRESH_SUCCESS)
    end

    def log_successful_revoke(refresh_token)
      sign_in_logger.refresh_token_log('revoke', refresh_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_SUCCESS)
    end

    def log_successful_logout(access_token)
      sign_in_logger.access_token_log('logout', access_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_SUCCESS)
    end

    def log_successful_revoke_all_sessions(access_token)
      sign_in_logger.access_token_log('revoke all sessions', access_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_SUCCESS)
    end

    def handle_callback_error(error, state_payload, state, code)
      context = { type: state_payload&.type, state: state, code: code }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE, tags: ["context:#{state_payload&.type}"])
      render json: { errors: error }, status: :bad_request
    end

    def handle_token_error(error)
      context = { code: params[:code], code_verifier: params[:code_verifier], grant_type: params[:grant_type] }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_FAILURE)
      render json: { errors: error }, status: :bad_request
    end

    def handle_refresh_error(error, status: :unauthorized)
      context = { refresh_token: params[:refresh_token], anti_csrf_token: params[:anti_csrf_token] }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REFRESH_FAILURE)
      render json: { errors: error }, status: status
    end

    def handle_revoke_error(error, status: :unauthorized)
      context = { refresh_token: params[:refresh_token], anti_csrf_token: params[:anti_csrf_token] }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_FAILURE)
      render json: { errors: error }, status: status
    end

    def handle_introspect_error(error)
      context = { user_uuid: @current_user.uuid }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_INTROSPECT_FAILURE)
      render json: { errors: error }, status: :unauthorized
    end

    def handle_logout_error(error)
      context = { user_uuid: @current_user.uuid }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE)
      render json: { errors: error }, status: :unauthorized
    end

    def handle_revoke_all_sessions_error(error)
      context = { user_uuid: @current_user.uuid }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_FAILURE)
      render json: { errors: error }, status: :unauthorized
    end

    def render_uplevel_credential(state_payload, state)
      acr_for_type = SignIn::AcrTranslator.new(acr: state_payload.acr, type: state_payload.type, uplevel: true).perform
      render body: auth_service(state_payload.type).render_auth(state: state, acr: acr_for_type),
             content_type: 'text/html'
    end

    def create_login_code(state_payload, user_info, credential_level, service_token_response)
      user_attributes = auth_service(state_payload.type).normalized_attributes(user_info, credential_level)
      SignIn::CredentialInfoCreator.new(csp_user_attributes: user_attributes,
                                        csp_token_response: service_token_response).perform
      user_code_map = SignIn::UserCreator.new(user_attributes: user_attributes, state_payload: state_payload).perform
      log_successful_callback(state_payload.type, state_payload.client_id)

      redirect_to SignIn::LoginRedirectUrlGenerator.new(user_code_map: user_code_map).perform
    end

    def token_cookies
      @token_cookies ||= defined?(cookies) ? cookies : nil
    end

    def delete_cookies
      cookies.delete(SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME)
      cookies.delete(SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME)
      cookies.delete(SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME)
      cookies.delete(SignIn::Constants::Auth::INFO_COOKIE_NAME)
    end

    def auth_service(type)
      case type
      when 'logingov'
        logingov_auth_service
      else
        idme_auth_service(type)
      end
    end

    def idme_auth_service(type)
      @idme_auth_service ||= begin
        @idme_auth_service = SignIn::Idme::Service.new
        @idme_auth_service.type = type
        @idme_auth_service
      end
    end

    def logingov_auth_service
      @logingov_auth_service ||= SignIn::Logingov::Service.new
    end

    def sign_in_logger
      @sign_in_logger = SignIn::Logger.new(prefix: self.class)
    end
  end
end
