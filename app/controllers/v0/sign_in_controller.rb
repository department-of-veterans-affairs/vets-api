# frozen_string_literal: true

require 'sign_in/logingov/service'
require 'sign_in/idme/service'
require 'sign_in/logger'

module V0
  class SignInController < SignIn::ApplicationController
    skip_before_action :authenticate, only: %i[authorize callback token refresh revoke]

    REDIRECT_URLS = %w[idme logingov dslogon mhv].freeze

    def authorize
      type = params[:type]
      client_state = params[:state]
      code_challenge = params[:code_challenge]
      code_challenge_method = params[:code_challenge_method]

      raise SignIn::Errors::AuthorizeInvalidType, 'Authorization type is not valid' unless REDIRECT_URLS.include?(type)
      raise SignIn::Errors::MalformedParamsError, 'Code Challenge is not defined' unless code_challenge
      raise SignIn::Errors::MalformedParamsError, 'Code Challenge Method is not defined' unless code_challenge_method

      state = SignIn::CodeChallengeStateMapper.new(code_challenge: code_challenge,
                                                   code_challenge_method: code_challenge_method,
                                                   client_state: client_state).perform
      attributes = { state: state,
                     type: type,
                     client_state: client_state,
                     code_challenge: code_challenge,
                     code_challenge_method: code_challenge_method }
      sign_in_logger.info_log('Sign in Service Authorization Attempt', attributes)

      render body: auth_service(type).render_auth(state: state), content_type: 'text/html'
    rescue SignIn::Errors::StandardError => e
      render json: { errors: e }, status: :bad_request
    end

    def callback
      type = params[:type]
      code = params[:code]
      state = params[:state]

      raise SignIn::Errors::CallbackInvalidType, 'Callback type is not valid' unless REDIRECT_URLS.include?(type)
      raise SignIn::Errors::MalformedParamsError, 'Code is not defined' unless code
      raise SignIn::Errors::MalformedParamsError, 'State is not defined' unless state

      login_code, client_state = login(type, state, code)
      attributes = { state: state, type: type, code: code, login_code: login_code, client_state: client_state }
      sign_in_logger.info_log('Sign in Service Authorization Callback', attributes)

      redirect_to login_redirect_url(login_code, client_state)
    rescue SignIn::Errors::StandardError => e
      render json: { errors: e }, status: :bad_request
    end

    def token
      code = params[:code]
      code_verifier = params[:code_verifier]
      grant_type = params[:grant_type]

      raise SignIn::Errors::MalformedParamsError, 'Code is not defined' unless code
      raise SignIn::Errors::MalformedParamsError, 'Code Verifier is not defined' unless code_verifier
      raise SignIn::Errors::MalformedParamsError, 'Grant Type is not defined' unless grant_type

      validated_credential = SignIn::CodeValidator.new(code: code,
                                                       code_verifier: code_verifier,
                                                       grant_type: grant_type).perform
      session_container = SignIn::SessionCreator.new(validated_credential: validated_credential).perform
      sign_in_logger.refresh_token_log('Sign in Service Token Response',
                                       session_container.refresh_token,
                                       { code: code })

      render json: session_token_response(session_container), status: :ok
    rescue SignIn::Errors::StandardError => e
      render json: { errors: e }, status: :bad_request
    end

    def refresh
      refresh_token = params[:refresh_token]
      anti_csrf_token = params[:anti_csrf_token]
      enable_anti_csrf = Settings.sign_in.enable_anti_csrf

      raise SignIn::Errors::MalformedParamsError, 'Refresh token is not defined' unless refresh_token
      if enable_anti_csrf && anti_csrf_token.nil?
        raise SignIn::Errors::MalformedParamsError, 'Anti CSRF token is not defined'
      end

      session_container = refresh_session(refresh_token, anti_csrf_token, enable_anti_csrf)
      sign_in_logger.refresh_token_log('Sign in Service Tokens Refresh', session_container.refresh_token)

      render json: session_token_response(session_container), status: :ok
    rescue SignIn::Errors::MalformedParamsError => e
      render json: { errors: e }, status: :bad_request
    rescue SignIn::Errors::StandardError => e
      render json: { errors: e }, status: :unauthorized
    end

    def revoke
      refresh_token = params[:refresh_token]
      anti_csrf_token = params[:anti_csrf_token]
      enable_anti_csrf = Settings.sign_in.enable_anti_csrf

      raise SignIn::Errors::MalformedParamsError, 'Refresh token is not defined' unless refresh_token
      if enable_anti_csrf && anti_csrf_token.nil?
        raise SignIn::Errors::MalformedParamsError, 'Anti CSRF token is not defined'
      end

      revoke_session(refresh_token, anti_csrf_token, enable_anti_csrf)

      render status: :ok
    rescue SignIn::Errors::MalformedParamsError => e
      render json: { errors: e }, status: :bad_request
    rescue SignIn::Errors::StandardError => e
      render json: { errors: e }, status: :unauthorized
    end

    def introspect
      sign_in_logger.access_token_log('Sign in Service Introspect', @access_token)

      render json: @current_user, serializer: SignIn::IntrospectSerializer, status: :ok
    rescue SignIn::Errors::StandardError => e
      render json: { errors: e }, status: :unauthorized
    end

    private

    def session_token_response(session_container)
      encrypt_refresh_token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
      encode_access_token = SignIn::AccessTokenJwtEncoder.new(access_token: session_container.access_token).perform

      token_json_response(encode_access_token, encrypt_refresh_token, session_container.anti_csrf_token)
    end

    def token_json_response(access_token, refresh_token, anti_csrf_token)
      {
        data:
          {
            access_token: access_token,
            refresh_token: refresh_token,
            anti_csrf_token: anti_csrf_token
          }
      }
    end

    def refresh_session(refresh_token, anti_csrf_token, enable_anti_csrf)
      SignIn::SessionRefresher.new(refresh_token: decrypted_refresh_token(refresh_token),
                                   anti_csrf_token: anti_csrf_token,
                                   enable_anti_csrf: enable_anti_csrf).perform
    end

    def revoke_session(refresh_token, anti_csrf_token, enable_anti_csrf)
      refresh_token = decrypted_refresh_token(refresh_token)
      sign_in_logger.refresh_token_log('Sign in Service Session Revoke', refresh_token)
      SignIn::SessionRevoker.new(refresh_token: refresh_token,
                                 anti_csrf_token: anti_csrf_token,
                                 enable_anti_csrf: enable_anti_csrf).perform
    end

    def decrypted_refresh_token(refresh_token)
      SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform
    end

    def login(type, state, code)
      response = auth_service(type).token(code)

      raise SignIn::Errors::CodeInvalidError, 'Authentication Code is not valid' unless response

      user_info = auth_service(type).user_info(response[:access_token])

      normalized_attributes = auth_service(type).normalized_attributes(user_info)

      SignIn::UserCreator.new(user_attributes: normalized_attributes, state: state).perform
    end

    def login_redirect_url(login_code, client_state = nil)
      redirect_uri_params = { code: login_code }
      redirect_uri_params[:state] = client_state if client_state.present?

      redirect_uri = URI.parse(Settings.sign_in.redirect_uri)
      redirect_uri.query = redirect_uri_params.to_query
      redirect_uri.to_s
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
      @sign_in_logger = SignIn::Logger.new
    end
  end
end
