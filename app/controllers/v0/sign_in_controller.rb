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

      delete_cookies if token_cookies

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
      log_post_login_event('token',
                           session_container.refresh_token,
                           SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS,
                           { code: code })

      serializer_response = SignIn::TokenSerializer.new(session_container: session_container,
                                                        cookies: token_cookies).perform
      render json: serializer_response, status: :ok
    rescue SignIn::Errors::StandardError => e
      handle_post_login_error(e, { code: code, code_verifier: code_verifier, grant_type: grant_type },
                              SignIn::Constants::Statsd::STATSD_SIS_TOKEN_FAILURE,
                              session_container&.session&.user_account_id, status: :bad_request)
    end

    def refresh
      refresh_token = params[:refresh_token] || token_cookies[SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME]
      anti_csrf_token = params[:anti_csrf_token] || token_cookies[SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME]

      raise SignIn::Errors::MalformedParamsError, 'Refresh token is not defined' unless refresh_token

      decrypted_refresh_token = SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
      session_container = SignIn::SessionRefresher.new(refresh_token: decrypted_refresh_token,
                                                       anti_csrf_token: anti_csrf_token).perform
      log_post_login_event('refresh', session_container.refresh_token,
                           SignIn::Constants::Statsd::STATSD_SIS_REFRESH_SUCCESS)

      serializer_response = SignIn::TokenSerializer.new(session_container: session_container,
                                                        cookies: token_cookies).perform
      render json: serializer_response, status: :ok
    rescue SignIn::Errors::MalformedParamsError => e
      handle_post_login_error(e, { refresh_token: refresh_token, anti_csrf_token: anti_csrf_token },
                              SignIn::Constants::Statsd::STATSD_SIS_REFRESH_FAILURE,
                              status: :bad_request)
    rescue SignIn::Errors::StandardError => e
      handle_post_login_error(e, { refresh_token: refresh_token, anti_csrf_token: anti_csrf_token },
                              SignIn::Constants::Statsd::STATSD_SIS_REFRESH_FAILURE,
                              session_container&.session&.user_account_id)
    end

    def revoke
      refresh_token = params[:refresh_token]
      anti_csrf_token = params[:anti_csrf_token]

      raise SignIn::Errors::MalformedParamsError, 'Refresh token is not defined' unless refresh_token

      decrypted_refresh_token = SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
      SignIn::SessionRevoker.new(refresh_token: decrypted_refresh_token,
                                 anti_csrf_token: anti_csrf_token,
                                 access_token: nil).perform
      log_post_login_event('revoke', decrypted_refresh_token, SignIn::Constants::Statsd::STATSD_SIS_REVOKE_SUCCESS)

      render status: :ok
    rescue SignIn::Errors::MalformedParamsError => e
      handle_post_login_error(e, { refresh_token: refresh_token, anti_csrf_token: anti_csrf_token },
                              SignIn::Constants::Statsd::STATSD_SIS_REVOKE_FAILURE,
                              status: :bad_request)
    rescue SignIn::Errors::StandardError => e
      handle_post_login_error(e, { refresh_token: refresh_token, anti_csrf_token: anti_csrf_token },
                              SignIn::Constants::Statsd::STATSD_SIS_REVOKE_FAILURE,
                              decrypted_refresh_token&.user_uuid)
    end

    def revoke_all_sessions
      SignIn::RevokeSessionsForUser.new(user_uuid: @current_user.uuid).perform
      log_post_login_event('revoke all sessions', @access_token,
                           SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_SUCCESS)

      render status: :ok
    rescue SignIn::Errors::StandardError => e
      handle_authenticated_route_error(e, SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_FAILURE)
    end

    def logout
      anti_csrf_token = params[:anti_csrf_token] || token_cookies[SignIn::Constants::Auth::ANTI_CSRF_COOKIE_NAME]

      SignIn::SessionRevoker.new(access_token: @access_token,
                                 refresh_token: nil,
                                 anti_csrf_token: anti_csrf_token).perform
      delete_cookies if token_cookies
      log_post_login_event('logout', @access_token, SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_SUCCESS)

      credential_info = SignIn::CredentialInfo.find(@current_user.logingov_uuid)
      if credential_info
        redirect_to auth_service(credential_info.credential_type).render_logout(id_token: credential_info.id_token)
      else
        render status: :ok
      end
    rescue SignIn::Errors::StandardError => e
      handle_authenticated_route_error(e, SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE)
    end

    def introspect
      log_post_login_event('introspect', @access_token, SignIn::Constants::Statsd::STATSD_SIS_INTROSPECT_SUCCESS)

      render json: @current_user, serializer: SignIn::IntrospectSerializer, status: :ok
    rescue SignIn::Errors::StandardError => e
      handle_authenticated_route_error(e, SignIn::Constants::Statsd::STATSD_SIS_INTROSPECT_FAILURE)
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
      context = { type: type, client_id: client_id, acr: acr }
      sign_in_logger.info('authorize', context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_SUCCESS,
                       tags: ["type:#{type}", "client_id:#{client_id}", "acr:#{acr}"])
    end

    def log_successful_callback(type, client_id, acr)
      context = { type: type, client_id: client_id, acr: acr }
      sign_in_logger.info('callback', context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS,
                       tags: ["type:#{type}", "client_id:#{client_id}", "acr:#{acr}"])
    end

    def log_post_login_event(event, token, statsd_code, context = {})
      auth_info = get_user_auth_info(User.find(token.user_uuid))
      context = context.merge({ type: auth_info[:type], client_id: auth_info[:client_id], loa: auth_info[:loa] })
      if token.instance_of?(SignIn::AccessToken)
        sign_in_logger.access_token_log(event, token, context)
      else
        sign_in_logger.refresh_token_log(event, token, context)
      end
      StatsD.increment(statsd_code,
                       tags: ["type:#{auth_info[:type]}",
                              "client_id:#{auth_info[:client_id]}",
                              "loa:#{auth_info[:loa]}"])
    end

    def handle_authorize_error(error, type, client_id, acr)
      context = { type: type, client_id: client_id, acr: acr }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_FAILURE,
                       tags: ["type:#{type}", "client_id:#{client_id}", "acr:#{acr}"])
      render json: { errors: error }, status: :bad_request
    end

    def handle_callback_error(error, state_payload, state, code)
      type = state_payload&.type
      client_id = state_payload&.client_id
      acr = state_payload&.acr
      context = { type: type, client_id: client_id, acr: acr, state: state, code: code }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE,
                       tags: ["type:#{type}", "client_id:#{client_id}", "acr:#{acr}"])
      render json: { errors: error }, status: :bad_request
    end

    def handle_post_login_error(error, context, statsd_code, user_id = nil, status: :unauthorized)
      auth_info = user_id ? get_user_auth_info(User.find(user_id)) : {}
      context = context.merge({ type: auth_info[:type], client_id: auth_info[:client_id], loa: auth_info[:loa] })
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(statsd_code,
                       tags: ["type:#{auth_info[:type]}",
                              "client_id:#{auth_info[:client_id]}",
                              "loa:#{auth_info[:loa]}"])
      render json: { errors: error }, status: status
    end

    def handle_authenticated_route_error(error, statsd_code)
      auth_info = get_user_auth_info
      context = { user_uuid: @current_user.uuid,
                  type: auth_info[:type],
                  client_id: auth_info[:client_id],
                  loa: auth_info[:loa] }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(statsd_code,
                       tags: ["type:#{auth_info[:type]}",
                              "client_id:#{auth_info[:client_id]}",
                              "loa:#{auth_info[:loa]}"])
      render json: { errors: error }, status: :unauthorized
    end

    def render_uplevel_credential(state_payload, state)
      acr_for_type = SignIn::AcrTranslator.new(acr: state_payload.acr, type: state_payload.type, uplevel: true).perform
      render body: auth_service(state_payload.type).render_auth(state: state, acr: acr_for_type),
             content_type: 'text/html'
    end

    def create_login_code(state_payload, user_info, credential_level, service_token_response)
      user_attributes = auth_service(state_payload.type).normalized_attributes(user_info, credential_level,
                                                                               state_payload.client_id)
      SignIn::CredentialInfoCreator.new(csp_user_attributes: user_attributes,
                                        csp_token_response: service_token_response).perform
      user_code_map = SignIn::UserCreator.new(user_attributes: user_attributes, state_payload: state_payload).perform
      log_successful_callback(state_payload.type, state_payload.client_id, state_payload.acr)

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

    def get_user_auth_info(user = @current_user)
      return {} unless user

      { type: user.identity.sign_in[:service_name],
        client_id: user.identity.sign_in[:client_id],
        loa: user.loa[:current] }
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
