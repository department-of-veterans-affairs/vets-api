# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'aes_256_cbc_encryptor'

class ApplicationController < ActionController::API
  include AuthenticationAndSSOConcerns
  include SentryLogging
  include Pundit

  VERSION_STATUS = {
    draft: 'Draft Version',
    current: 'Current Version',
    previous: 'Previous Version',
    deprecated: 'Deprecated Version'
  }.freeze

  prepend_before_action :block_unknown_hosts, :set_app_info_headers
  skip_before_action :authenticate, only: %i[cors_preflight routing_error] # @see {AuthenticationAndSSOConcerns}
  before_action :set_tags_and_extra_context                                # @see {SentryLogging}

  def cors_preflight
    head(:ok)
  end

  def routing_error
    raise Common::Exceptions::RoutingError, params[:path]
  end

  def clear_saved_form(form_id)
    InProgressForm.form_for_user(form_id, current_user)&.destroy if current_user
  end

  private

  attr_reader :current_user

  rescue_from 'StandardError' do |error|
    handler = Common::Client::Errors::ErrorHandler.new(error)
    handler.log_error

    va_exception = handler.va_exception
    set_empty_auth_header if va_exception.is_a?(Common::Exceptions::Unauthorized)

    render json: { errors: va_exception.errors }, status: va_exception.status_code
  end

  # returns a Bad Request if the incoming host header is unsafe.
  def block_unknown_hosts
    return if controller_name == 'example'
    raise Common::Exceptions::NotASafeHostError, request.host unless Settings.virtual_hosts.include?(request.host)
  end

  def set_app_info_headers
    headers['X-Git-SHA']           = AppInfo::GIT_REVISION
    headers['X-GitHub-Repository'] = AppInfo::GITHUB_REPO
  end

  def set_empty_auth_header
    headers['WWW-Authenticate'] = 'Token realm="Application"'
  end

  def saml_settings(options = {})
    callback_url = URI.parse(Settings.saml.callback_url)
    callback_url.host = request.host
    options.reverse_merge!(assertion_consumer_service_url: callback_url.to_s)
    SAML::SettingsService.saml_settings(options)
  end

  def pagination_params
    {
      page: params[:page],
      per_page: params[:per_page]
    }
  end

  def render_job_id(jid)
    render json: { job_id: jid }, status: :accepted
  end

  def append_info_to_payload(payload)
    super
    payload[:session] = Session.obscure_token(session[:token]) if session && session[:token]
    payload[:user_uuid] = current_user.uuid if current_user.present?
  end
end
