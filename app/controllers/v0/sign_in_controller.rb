# frozen_string_literal: true

require 'sign_in/logger'

module V0
  class SignInController < SignIn::ApplicationController
    include SignIn::SSOAuthorizable

    skip_before_action :authenticate,
                       only: %i[authorize callback token refresh revoke revoke_all_sessions logout
                                logingov_logout_proxy]
    before_action :access_token_authenticate, only: :revoke_all_sessions

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
                                                 operation:,
                                                 client_state:,
                                                 scope:).perform
      context = { type:, client_id:, acr:, operation: }

      sign_in_logger.info('authorize', context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_SUCCESS,
                       tags: ["type:#{type}", "client_id:#{client_id}", "acr:#{acr}", "operation:#{operation}"])

      render body: auth_service(type, client_id).render_auth(state:, acr: acr_for_type, operation:),
             content_type: 'text/html'
    rescue => e
      sign_in_logger.info('authorize error', { errors: e.message, client_id:, type:, acr:, operation: })
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE)
      handle_pre_login_error(e, client_id)
    end

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
    rescue => e
      error_details = {
        type: state_payload&.type,
        client_id: state_payload&.client_id,
        acr: state_payload&.acr,
        operation: state_payload&.operation
      }
      sign_in_logger.info('callback error', error_details.merge(errors: e.message))
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE,
                       tags: ["type:#{error_details[:type]}",
                              "client_id:#{error_details[:client_id]}",
                              "acr:#{error_details[:acr]}",
                              "operation:#{error_details[:operation]}"])
      handle_pre_login_error(e, state_payload&.client_id)
    end

    def token
      SignIn::TokenParamsValidator.new(params: token_params).perform
      request_attributes = { remote_ip: request.remote_ip, user_agent: request.user_agent }
      response_body = SignIn::TokenResponseGenerator.new(params: token_params,
                                                         cookies: token_cookies,
                                                         request_attributes:).perform
      sign_in_logger.info('token')
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS)

      render json: response_body, status: :ok
    rescue SignIn::Errors::StandardError => e
      sign_in_logger.info('token error', { errors: e.message, grant_type: token_params[:grant_type] })
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_FAILURE)
      render json: { errors: e }, status: :bad_request
    end

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

    def logout # rubocop:disable Metrics/MethodLength
      client_id = params[:client_id].presence
      anti_csrf_token = anti_csrf_token_param.presence

      if client_config(client_id).blank?
        raise SignIn::Errors::MalformedParamsError.new message: 'Client id is not valid'
      end

      unless access_token_authenticate(skip_render_error: true)
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
      sign_in_logger.info('logout error', { errors: e.message, client_id: })
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE)
      logout_redirect = SignIn::LogoutRedirectGenerator.new(client_config: client_config(client_id)).perform

      logout_redirect ? redirect_to(logout_redirect) : render(status: :ok)
    rescue => e
      sign_in_logger.info('logout error', { errors: e.message, client_id: })
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

    def validate_callback_params(code, state, error)
      raise SignIn::Errors::MalformedParamsError.new message: 'Code is not defined' unless code || error
      raise SignIn::Errors::MalformedParamsError.new message: 'State is not defined' unless state
    end

    def token_params
      params.permit(:grant_type, :code, :code_verifier, :client_assertion, :client_assertion_type,
                    :assertion, :subject_token, :subject_token_type, :actor_token, :actor_token_type, :client_id)
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
      acr_for_type = SignIn::AcrTranslator.new(acr: state_payload.acr, type: state_payload.type, uplevel: true).perform
      state = SignIn::StatePayloadJwtEncoder.new(code_challenge: state_payload.code_challenge,
                                                 code_challenge_method: SignIn::Constants::Auth::CODE_CHALLENGE_METHOD,
                                                 acr: state_payload.acr,
                                                 client_config: client_config(state_payload.client_id),
                                                 type: state_payload.type,
                                                 client_state: state_payload.client_state,
                                                 operation: state_payload.operation).perform
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
        credential_uuid: user_info.sub,
        authentication_time: Time.zone.now.to_i - state_payload.created_at,
        operation: state_payload.operation
      }
      sign_in_logger.info('callback', context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS,
                       tags: ["type:#{state_payload.type}",
                              "client_id:#{state_payload.client_id}",
                              "ial:#{credential_level.current_ial}",
                              "acr:#{state_payload.acr}",
                              "operation:#{state_payload.operation}"])
      params_hash = { code: user_code_map.login_code, type: user_code_map.type }
      params_hash.merge!(state: user_code_map.client_state) if user_code_map.client_state.present?

      render body: SignIn::RedirectUrlGenerator.new(redirect_uri: user_code_map.client_config.redirect_uri,
                                                    terms_code: user_code_map.terms_code,
                                                    terms_redirect_uri: user_code_map.client_config.terms_of_use_url,
                                                    params_hash:).perform,
             content_type: 'text/html'
    end

    def refresh_token_param
      params[:refresh_token] || token_cookies[SignIn::Constants::Auth::REFRESH_TOKEN_COOKIE_NAME]
    end

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
      cookies.delete(SignIn::Constants::Auth::INFO_COOKIE_NAME, domain: IdentitySettings.sign_in.info_cookie_domain)
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
