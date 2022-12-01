# frozen_string_literal: true

require 'sign_in/logingov/service'
require 'sign_in/idme/service'
require 'sign_in/logger'

module V0
  class SignInController < SignIn::ApplicationController
    skip_before_action :authenticate, only: %i[authorize callback token refresh revoke logout]

    def authorize # rubocop:disable Metrics/MethodLength
      type = params[:type].presence
      client_state = params[:state].presence
      code_challenge = params[:code_challenge].presence
      code_challenge_method = params[:code_challenge_method].presence
      client_id = params[:client_id].presence
      acr = params[:acr].presence

      validate_authorize_params(type, client_id, code_challenge, code_challenge_method, acr)

      delete_cookies if token_cookies

      acr_for_type = SignIn::AcrTranslator.new(acr: acr, type: type).perform
      state = SignIn::StatePayloadJwtEncoder.new(code_challenge: code_challenge,
                                                 code_challenge_method: code_challenge_method,
                                                 acr: acr, client_id: client_id,
                                                 type: type, client_state: client_state).perform
      context = { type: type, client_id: client_id, acr: acr }

      sign_in_logger.info('authorize', context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_SUCCESS,
                       tags: ["type:#{context[:type]}", "client_id:#{context[:client_id]}", "acr:#{context[:acr]}"])

      render body: auth_service(type).render_auth(state: state, acr: acr_for_type), content_type: 'text/html'
    rescue SignIn::Errors::StandardError => e
      sign_in_logger.info('authorize error', { errors: e.message, client_id: client_id, type: type, acr: acr })
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
      SignIn::StatePayloadVerifier.new(state_payload: state_payload).perform

      handle_credential_provider_error(error, state_payload&.type) if error
      service_token_response = auth_service(state_payload.type).token(code)

      raise SignIn::Errors::CodeInvalidError, message: 'Code is not valid' unless service_token_response

      user_info = auth_service(state_payload.type).user_info(service_token_response[:access_token])
      credential_level = SignIn::CredentialLevelCreator.new(requested_acr: state_payload.acr,
                                                            type: state_payload.type,
                                                            id_token: service_token_response[:id_token],
                                                            user_info: user_info).perform
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

      validate_token_params(code, code_verifier, grant_type)

      validated_credential = SignIn::CodeValidator.new(code: code,
                                                       code_verifier: code_verifier,
                                                       grant_type: grant_type).perform
      session_container = SignIn::SessionCreator.new(validated_credential: validated_credential).perform
      serializer_response = SignIn::TokenSerializer.new(session_container: session_container,
                                                        cookies: token_cookies).perform

      sign_in_logger.token_log('token', session_container.access_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_SUCCESS)

      render json: serializer_response, status: :ok
    rescue SignIn::Errors::StandardError => e
      sign_in_logger.info('token error', { errors: e.message })
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_TOKEN_FAILURE)
      render json: { errors: e }, status: :bad_request
    end

    def refresh
      refresh_token = refresh_token_param.presence
      anti_csrf_token = anti_csrf_token_param.presence

      raise SignIn::Errors::MalformedParamsError, message: 'Refresh token is not defined' unless refresh_token

      decrypted_refresh_token = SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
      session_container = SignIn::SessionRefresher.new(refresh_token: decrypted_refresh_token,
                                                       anti_csrf_token: anti_csrf_token).perform
      serializer_response = SignIn::TokenSerializer.new(session_container: session_container,
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

      raise SignIn::Errors::MalformedParamsError, message: 'Refresh token is not defined' unless refresh_token

      decrypted_refresh_token = SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
      SignIn::SessionRevoker.new(refresh_token: decrypted_refresh_token, anti_csrf_token: anti_csrf_token).perform

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

    def logout
      anti_csrf_token = anti_csrf_token_param.presence

      unless load_user(skip_expiration_check: true)
        raise SignIn::Errors::LogoutAuthorizationError, message: 'Unable to Authorize User'
      end

      SignIn::SessionRevoker.new(access_token: @access_token, anti_csrf_token: anti_csrf_token).perform
      delete_cookies if token_cookies

      sign_in_logger.token_log('logout', @access_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_SUCCESS)
    rescue => e
      sign_in_logger.info('logout error', { errors: e.message })
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE)
    ensure
      redirect_to logout_get_redirect_url
    end

    def introspect
      render json: @current_user, serializer: SignIn::IntrospectSerializer, status: :ok
    rescue SignIn::Errors::StandardError => e
      render json: { errors: e }, status: :unauthorized
    end

    private

    def validate_authorize_params(type, client_id, code_challenge, code_challenge_method, acr)
      unless SignIn::Constants::ClientConfig::CLIENT_IDS.include?(client_id)
        raise SignIn::Errors::MalformedParamsError, message: 'Client id is not valid'
      end
      unless SignIn::Constants::Auth::CSP_TYPES.include?(type)
        raise SignIn::Errors::AuthorizeInvalidType, message: 'Type is not valid'
      end
      unless SignIn::Constants::Auth::ACR_VALUES.include?(acr)
        raise SignIn::Errors::MalformedParamsError, message: 'ACR is not valid'
      end
      raise SignIn::Errors::MalformedParamsError, message: 'Code Challenge is not defined' unless code_challenge
      unless code_challenge_method
        raise SignIn::Errors::MalformedParamsError, message: 'Code Challenge Method is not defined'
      end
    end

    def validate_callback_params(code, state, error)
      raise SignIn::Errors::MalformedParamsError, message: 'Code is not defined' unless code || error
      raise SignIn::Errors::MalformedParamsError, message: 'State is not defined' unless state
    end

    def validate_token_params(code, code_verifier, grant_type)
      raise SignIn::Errors::MalformedParamsError, message: 'Code is not defined' unless code
      raise SignIn::Errors::MalformedParamsError, message: 'Code Verifier is not defined' unless code_verifier
      raise SignIn::Errors::MalformedParamsError, message: 'Grant Type is not defined' unless grant_type
    end

    def logout_get_redirect_url
      cspid = @current_user.nil? ? nil : @current_user.identity.sign_in[:service_name]
      if cspid == SAML::User::LOGINGOV_CSID
        auth_service(cspid).render_logout
      else
        URI.parse(Settings.sign_in.client_redirect_uris.web_logout).to_s
      end
    end

    def handle_pre_login_error(error, client_id)
      if SignIn::Constants::ClientConfig::COOKIE_AUTH.include?(client_id)
        error_code = error.try(:code) || SignIn::Constants::ErrorCode::INVALID_REQUEST
        redirect_to failed_auth_url({ auth: 'fail', code: error_code, request_id: request.request_id })
      else
        render json: { errors: error }, status: :bad_request
      end
    end

    def handle_credential_provider_error(error, type)
      if error == SignIn::Constants::Auth::ACCESS_DENIED
        error_message = 'User Declined to Authorize Client'
        error_code = if type == SAML::User::LOGINGOV_CSID
                       SignIn::Constants::ErrorCode::LOGINGOV_VERIFICATION_DENIED
                     else
                       SignIn::Constants::ErrorCode::IDME_VERIFICATION_DENIED
                     end
        raise SignIn::Errors::AccessDeniedError, message: error_message, code: error_code
      else
        error_message = 'Unknown Credential Provider Issue'
        error_code = SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE
        raise SignIn::Errors::CredentialProviderError, message: error_message, code: error_code
      end
    end

    def failed_auth_url(params)
      uri = URI.parse(Settings.sign_in.client_redirect_uris.web)
      uri.query = params.to_query
      uri.to_s
    end

    def render_uplevel_credential(state_payload)
      acr_for_type = SignIn::AcrTranslator.new(acr: state_payload.acr, type: state_payload.type, uplevel: true).perform
      state = SignIn::StatePayloadJwtEncoder.new(code_challenge: state_payload.code_challenge,
                                                 code_challenge_method: SignIn::Constants::Auth::CODE_CHALLENGE_METHOD,
                                                 acr: state_payload.acr, client_id: state_payload.client_id,
                                                 type: state_payload.type,
                                                 client_state: state_payload.client_state).perform
      render body: auth_service(state_payload.type).render_auth(state: state, acr: acr_for_type),
             content_type: 'text/html'
    end

    def create_login_code(state_payload, user_info, credential_level)
      user_attributes = auth_service(state_payload.type).normalized_attributes(user_info, credential_level)
      verified_icn = SignIn::AttributeValidator.new(user_attributes: user_attributes).perform
      user_code_map = SignIn::UserCreator.new(user_attributes: user_attributes,
                                              state_payload: state_payload,
                                              verified_icn: verified_icn,
                                              request_ip: request.ip).perform
      context = {
        type: state_payload.type,
        client_id: state_payload.client_id,
        ial: credential_level.current_ial,
        acr: state_payload.acr
      }
      sign_in_logger.info('callback', context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS,
                       tags: ["type:#{context[:type]}",
                              "client_id:#{context[:client_id]}",
                              "ial:#{context[:ial]}",
                              "acr:#{context[:acr]}"])

      redirect_to SignIn::LoginRedirectUrlGenerator.new(user_code_map: user_code_map).perform
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

    def auth_service(type)
      case type
      when SAML::User::LOGINGOV_CSID
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
