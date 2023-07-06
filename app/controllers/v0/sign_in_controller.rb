# frozen_string_literal: true

require 'sign_in/logger'

module V0
  class SignInController < SignIn::ApplicationController
    skip_before_action :authenticate,
                       only: %i[authorize callback token refresh revoke logout logingov_logout_proxy
                                read_client_config]

    def authorize # rubocop:disable Metrics/MethodLength
      type = params[:type].presence
      client_state = params[:state].presence
      code_challenge = params[:code_challenge].presence
      code_challenge_method = params[:code_challenge_method].presence
      client_id = params[:client_id].presence
      acr = params[:acr].presence

      validate_authorize_params(type, client_id, acr)

      delete_cookies if token_cookies

      acr_for_type = SignIn::AcrTranslator.new(acr:, type:).perform
      state = SignIn::StatePayloadJwtEncoder.new(code_challenge:,
                                                 code_challenge_method:,
                                                 acr:,
                                                 client_config: client_config(client_id),
                                                 type:,
                                                 client_state:).perform
      context = { type:, client_id:, acr: }

      sign_in_logger.info('authorize', context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_SUCCESS,
                       tags: ["type:#{type}", "client_id:#{client_id}", "acr:#{acr}"])

      render body: auth_service(type, client_id).render_auth(state:, acr: acr_for_type), content_type: 'text/html'
    rescue SignIn::Errors::StandardError => e
      sign_in_logger.info('authorize error', { errors: e.message, client_id:, type:, acr: })
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE)
      handle_pre_login_error(e, client_id)
    rescue => e
      log_message_to_sentry(e.message, :error)
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
                                                            id_token: service_token_response[:id_token],
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

    def token
      code = params[:code].presence
      code_verifier = params[:code_verifier].presence
      grant_type = params[:grant_type].presence
      client_assertion = params[:client_assertion].presence
      client_assertion_type = params[:client_assertion_type].presence
      service_account_assertion = params[:service_account_assertion].presence

      validate_token_params(code, service_account_assertion, grant_type)
      response_body =
        if grant_type == SignIn::Constants::Auth::JWT_BEARER
          generate_service_account_token(service_account_assertion, grant_type)
        else
          generate_user_token(code, code_verifier, client_assertion, client_assertion_type, grant_type)
        end
      render json: response_body, status: :ok
    rescue SignIn::Errors::StandardError => e
      sign_in_logger.info('token error', { errors: e.message })
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

      sign_in_logger.token_log('refresh', session_container.access_token)
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

      raise SignIn::Errors::MalformedParamsError.new message: 'Refresh token is not defined' unless refresh_token

      decrypted_refresh_token = SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
      SignIn::SessionRevoker.new(refresh_token: decrypted_refresh_token, anti_csrf_token:).perform

      sign_in_logger.token_log('revoke', decrypted_refresh_token)
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
      SignIn::RevokeSessionsForUser.new(user_account: @current_user.user_account).perform

      sign_in_logger.token_log('revoke all sessions', @access_token)
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

      unless load_user(skip_expiration_check: true)
        raise SignIn::Errors::LogoutAuthorizationError.new message: 'Unable to Authorize User'
      end

      SignIn::SessionRevoker.new(access_token: @access_token, anti_csrf_token:).perform
      delete_cookies if token_cookies

      sign_in_logger.token_log('logout', @access_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_SUCCESS)

      logout_redirect = SignIn::LogoutRedirectGenerator.new(user: @current_user,
                                                            client_config: client_config(client_id)).perform

      logout_redirect ? redirect_to(logout_redirect) : render(status: :ok)
    rescue SignIn::Errors::LogoutAuthorizationError, SignIn::Errors::SessionNotAuthorizedError => e
      sign_in_logger.info('logout error', { errors: e.message })
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE)

      logout_redirect = SignIn::LogoutRedirectGenerator.new(user: @current_user,
                                                            client_config: client_config(client_id)).perform

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

    def introspect
      render json: @current_user, serializer: SignIn::IntrospectSerializer, status: :ok
    rescue SignIn::Errors::StandardError => e
      render json: { errors: e }, status: :unauthorized
    end

    # test method for Service Account access token auth
    def read_client_config
      authenticate_service_account
    end

    private

    def validate_authorize_params(type, client_id, acr)
      if client_config(client_id).blank?
        raise SignIn::Errors::MalformedParamsError.new message: 'Client id is not valid'
      end
      unless SignIn::Constants::Auth::CSP_TYPES.include?(type)
        raise SignIn::Errors::AuthorizeInvalidType.new message: 'Type is not valid'
      end
      unless SignIn::Constants::Auth::ACR_VALUES.include?(acr)
        raise SignIn::Errors::MalformedParamsError.new message: 'ACR is not valid'
      end
    end

    def validate_callback_params(code, state, error)
      raise SignIn::Errors::MalformedParamsError.new message: 'Code is not defined' unless code || error
      raise SignIn::Errors::MalformedParamsError.new message: 'State is not defined' unless state
    end

    def validate_token_params(code, service_account_assertion, grant_type)
      raise SignIn::Errors::MalformedParamsError.new message: 'Grant Type is not defined' unless grant_type

      case grant_type
      when SignIn::Constants::Auth::AUTH_CODE
        raise SignIn::Errors::MalformedParamsError.new message: 'Code is not defined' unless code
      when SignIn::Constants::Auth::JWT_BEARER
        unless service_account_assertion
          raise SignIn::Errors::MalformedParamsError.new message: 'Service Account Assertion is not defined'
        end
      else
        raise SignIn::Errors::GrantTypeValueError.new message: 'Grant Type is not valid'
      end
    end

    def generate_service_account_token(service_account_assertion, grant_type)
      decoded_service_account_assertion =
        SignIn::ServiceAccountValidator.new(service_account_assertion:, grant_type:).perform
      service_account_access_token =
        SignIn::ServiceAccountAccessTokenJwtEncoder.new(decoded_service_account_assertion:).perform

      sign_in_logger.token_log('service_account token',
                               service_account_access_token,
                               { service_account_id: decoded_service_account_assertion.service_account_id })
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS)
      { data: { service_account_access_token: } }
    end

    def generate_user_token(code, code_verifier, client_assertion, client_assertion_type, grant_type)
      validated_credential = SignIn::CodeValidator.new(code:,
                                                       code_verifier:,
                                                       client_assertion:,
                                                       client_assertion_type:,
                                                       grant_type:).perform
      session_container = SignIn::SessionCreator.new(validated_credential:).perform
      sign_in_logger.token_log('token', session_container.access_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS)
      SignIn::TokenSerializer.new(session_container:, cookies: token_cookies).perform
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
                                                 client_state: state_payload.client_state).perform
      render body: auth_service(state_payload.type,
                                state_payload.client_id).render_auth(state:, acr: acr_for_type),
             content_type: 'text/html'
    end

    def create_login_code(state_payload, user_info, credential_level) # rubocop:disable Metrics/MethodLength
      user_attributes = auth_service(state_payload.type,
                                     state_payload.client_id).normalized_attributes(user_info, credential_level)
      verified_icn = SignIn::AttributeValidator.new(user_attributes:).perform
      user_code_map = SignIn::UserCreator.new(user_attributes:,
                                              state_payload:,
                                              verified_icn:,
                                              request_ip: request.ip).perform
      context = {
        type: state_payload.type,
        client_id: state_payload.client_id,
        ial: credential_level.current_ial,
        acr: state_payload.acr
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
      cookies.delete(SignIn::Constants::Auth::ACCESS_TOKEN_COOKIE_NAME)
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
      @client_config ||= SignIn::ClientConfig.find_by(client_id:)
    end

    def sign_in_logger
      @sign_in_logger = SignIn::Logger.new(prefix: self.class)
    end
  end
end
