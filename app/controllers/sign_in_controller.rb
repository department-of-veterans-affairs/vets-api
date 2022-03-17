# frozen_string_literal: true

require 'sign_in/logingov/service'

class SignInController < ApplicationController
  skip_before_action :verify_authenticity_token, :authenticate
  before_action :authenticate_access_token, only: [:introspect]

  REDIRECT_URLS = %w[idme logingov].freeze
  BEARER_PATTERN = /^Bearer /.freeze

  def authorize
    type = authorize_params[:type]
    code_challenge = authorize_params[:code_challenge]
    code_challenge_method = authorize_params[:code_challenge_method]

    raise SignIn::Errors::AuthorizeInvalidType unless SignInController::REDIRECT_URLS.include?(type)
    raise SignIn::Errors::MalformedParamsError unless code_challenge && code_challenge_method

    state = SignIn::CodeChallengeStateMapper.new(code_challenge: code_challenge,
                                                 code_challenge_method: code_challenge_method).perform
    render body: auth_service(type).render_auth(state: state), content_type: 'text/html'
  rescue => e
    render json: { errors: e }, status: :bad_request
  end

  def callback
    type = callback_params[:type]
    code = callback_params[:code]
    state = callback_params[:state]

    raise SignIn::Errors::CallbackInvalidType unless SignInController::REDIRECT_URLS.include?(type)
    raise SignIn::Errors::MalformedParamsError unless code && state

    login_code = login(type, state, code)
    redirect_to login_redirect_url(login_code)
  rescue => e
    render json: { errors: e }, status: :bad_request
  end

  def token
    code = token_params[:code]
    code_verifier = token_params[:code_verifier]
    grant_type = token_params[:grant_type]

    raise SignIn::Errors::MalformedParamsError unless code && code_verifier && grant_type

    user_account = SignIn::CodeValidator.new(code: code, code_verifier: code_verifier, grant_type: grant_type).perform
    session_container = SignIn::SessionCreator.new(user_account: user_account).perform

    render json: session_token_response(session_container), status: :ok
  rescue => e
    render json: { errors: e }, status: :unauthorized
  end

  def refresh
    refresh_token = refresh_params[:refresh_token]
    anti_csrf_token = refresh_params[:anti_csrf_token]
    enable_anti_csrf = Settings.sign_in.enable_anti_csrf

    raise SignIn::Errors::MalformedParamsError unless refresh_token
    raise SignIn::Errors::MalformedParamsError if enable_anti_csrf && anti_csrf_token.nil?

    session_container = refresh_session(refresh_token, anti_csrf_token, enable_anti_csrf)

    render json: session_token_response(session_container), status: :ok
  rescue => e
    render json: { errors: e }, status: :unauthorized
  end

  def introspect
    render json: { user_uuid: @current_user.uuid, icn: @current_user.icn }, status: :ok
  rescue => e
    render json: { errors: e }, status: :unauthorized
  end

  private

  def session_token_response(session_container)
    encrypted_refresh_token = SignIn::RefreshTokenEncryptor.new(refresh_token: session_container.refresh_token).perform
    encoded_access_token = SignIn::AccessTokenJwtEncoder.new(access_token: session_container.access_token).perform

    token_json_response(encoded_access_token, encrypted_refresh_token, session_container.anti_csrf_token)
  end

  def bearer_token(with_validation: true)
    header = request.authorization
    access_token_jwt = header.gsub(BEARER_PATTERN, '') if header&.match(BEARER_PATTERN)
    SignIn::AccessTokenJwtDecoder.new(access_token_jwt: access_token_jwt).perform(with_validation: with_validation)
  end

  def authenticate_access_token
    access_token = bearer_token

    @current_user = User.find(access_token.user_uuid)
  rescue => e
    render json: { errors: e }, status: :unauthorized
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
    decrypted_refresh_token = SignIn::RefreshTokenDecryptor.new(encrypted_refresh_token: refresh_token).perform

    SignIn::SessionRefresher.new(refresh_token: decrypted_refresh_token,
                                 anti_csrf_token: anti_csrf_token,
                                 enable_anti_csrf: enable_anti_csrf).perform
  end

  def login(type, state, code)
    response = auth_service(type).token(code)

    raise SignIn::Errors::CodeInvalidError unless response

    user_info = auth_service(type).user_info(response[:access_token])

    normalized_attributes = auth_service(type).normalized_attributes(user_info)

    SignIn::UserCreator.new(user_attributes: normalized_attributes, state: state).perform
  end

  def login_redirect_url(login_code)
    redirect_uri = URI.parse(Settings.sign_in.redirect_uri)
    redirect_uri.query = { code: login_code }.to_query
    redirect_uri.to_s
  end

  def auth_service(type)
    case type
    when 'idme'
      idme_auth_service
    when 'logingov'
      logingov_auth_service
    end
  end

  def idme_auth_service
    # @idme_auth_service ||= AuthIdme::Service.new
  end

  def logingov_auth_service
    @logingov_auth_service ||= SignIn::Logingov::Service.new
  end

  def authorize_params
    params.permit(:type, :code_challenge, :code_challenge_method)
  end

  def callback_params
    params.permit(:code, :type, :state)
  end

  def token_params
    params.permit(:code, :code_verifier, :grant_type)
  end

  def refresh_params
    params.permit(:refresh_token, :anti_csrf_token)
  end
end
