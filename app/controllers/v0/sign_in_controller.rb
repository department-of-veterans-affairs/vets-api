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

      validate_authorize_params(type, client_id, code_challenge, code_challenge_method)
      state = SignIn::CodeChallengeStateMapper.new(code_challenge: code_challenge,
                                                   code_challenge_method: code_challenge_method,
                                                   client_id: client_id,
                                                   client_state: client_state).perform
      log_successful_authorize(type, state, client_state, code_challenge, code_challenge_method, client_id)

      render body: auth_service(type).render_auth(state: state), content_type: 'text/html'
    rescue SignIn::Errors::StandardError => e
      handle_authorize_error(e, type, client_state, code_challenge, code_challenge_method, client_id)
    end

    def callback
      type = params[:type]
      code = params[:code]
      state = params[:state]

      validate_callback_params(type, code, state)
      user_code_map = create_user_code_map(type, state, code)
      log_successful_callback(state, type, code, user_code_map)

      redirect_to SignIn::LoginRedirectUrlGenerator.new(user_code_map: user_code_map).perform
    rescue SignIn::Errors::StandardError => e
      handle_callback_error(e, type, state, code)
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
                                 anti_csrf_token: anti_csrf_token).perform
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

    def introspect
      sign_in_logger.access_token_log('introspect', @access_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_INTROSPECT_SUCCESS)

      render json: @current_user, serializer: SignIn::IntrospectSerializer, status: :ok
    rescue SignIn::Errors::StandardError => e
      handle_introspect_error(e)
    end

    private

    def validate_authorize_params(type, client_id, code_challenge, code_challenge_method)
      unless SignIn::Constants::ClientConfig::CLIENT_IDS.include?(client_id)
        raise SignIn::Errors::MalformedParamsError, 'Client id is not valid'
      end
      unless SignIn::Constants::Auth::REDIRECT_URLS.include?(type)
        raise SignIn::Errors::AuthorizeInvalidType, 'Authorization type is not valid'
      end
      raise SignIn::Errors::MalformedParamsError, 'Code Challenge is not defined' unless code_challenge
      raise SignIn::Errors::MalformedParamsError, 'Code Challenge Method is not defined' unless code_challenge_method
    end

    def validate_callback_params(type, code, state)
      unless SignIn::Constants::Auth::REDIRECT_URLS.include?(type)
        raise SignIn::Errors::CallbackInvalidType, 'Callback type is not valid'
      end
      raise SignIn::Errors::MalformedParamsError, 'Code is not defined' unless code
      raise SignIn::Errors::MalformedParamsError, 'State is not defined' unless state
    end

    def validate_token_params(code, code_verifier, grant_type)
      raise SignIn::Errors::MalformedParamsError, 'Code is not defined' unless code
      raise SignIn::Errors::MalformedParamsError, 'Code Verifier is not defined' unless code_verifier
      raise SignIn::Errors::MalformedParamsError, 'Grant Type is not defined' unless grant_type
    end

    # rubocop:disable Metrics/ParameterLists
    def log_successful_authorize(type, state, client_state, code_challenge, code_challenge_method, client_id)
      attributes = {
        state: state,
        type: type,
        client_state: client_state,
        code_challenge: code_challenge,
        code_challenge_method: code_challenge_method,
        client_id: client_id
      }
      sign_in_logger.info('authorize', attributes)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_SUCCESS, tags: ["context:#{type}"])
    end

    def handle_authorize_error(error, type, client_state, code_challenge, code_challenge_method, client_id)
      context = {
        type: type,
        client_state: client_state,
        code_challenge: code_challenge,
        code_challenge_method: code_challenge_method,
        client_id: client_id
      }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_ATTEMPT_FAILURE, tags: ["context:#{type}"])
      render json: { errors: error }, status: :bad_request
    end
    # rubocop:enable Metrics/ParameterLists

    def log_successful_callback(state, type, code, user_code_map)
      attributes = {
        state: state,
        type: type,
        code: code,
        login_code: user_code_map.login_code,
        client_id: user_code_map.client_id,
        client_state: user_code_map.client_state
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

    def log_successful_revoke_all_sessions(access_token)
      sign_in_logger.access_token_log('revoke all sessions', access_token)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_SUCCESS)
    end

    def create_user_code_map(type, state, code)
      response = auth_service(type).token(code)
      raise SignIn::Errors::CodeInvalidError, 'Authentication Code is not valid' unless response

      user_info = auth_service(type).user_info(response[:access_token])
      normalized_attributes = auth_service(type).normalized_attributes(user_info)
      SignIn::UserCreator.new(user_attributes: normalized_attributes, state: state, type: type).perform
    end

    def handle_callback_error(error, type, state, code)
      context = { type: type, state: state, code: code }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE, tags: ["context:#{type}"])
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

    def handle_revoke_all_sessions_error(error)
      context = { user_uuid: @current_user.uuid }
      log_message_to_sentry(error.message, :error, context)
      StatsD.increment(SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_FAILURE)
      render json: { errors: error }, status: :unauthorized
    end

    def token_cookies
      @token_cookies ||= defined?(cookies) ? cookies : nil
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
