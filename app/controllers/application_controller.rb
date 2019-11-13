# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'aes_256_cbc_encryptor'

##
# @attr_reader [User] current_user returns the current user object, if it exists
# @raise [Common::Exceptions::Forbidden] when encountering a Pundit::NotAuthorizedError
# @raise [Common::Exceptions::NotASafeHostError] when incoming host header is unsafe
# @raise [Common::Exceptions::ParameterMissing] when encountering an ActionController::ParameterMissing error
# @raise [Common::Exceptions::RoutingError] when encountering a routing error
# @raise [Common::Exceptions::ServiceOutage] when a Breakers::OutageException indicates a service degredation
# @raise [Common::Exceptions::UnknownFormat] when encountering an ActionController::UnknownFormat error
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

  ##
  # This method is responsible for clearing a saved {InProgressForm} for the current user
  # @param form_id the ID of the InProgressForm to clear
  # @return Boolean true if the InProgressForm is successfully deleted
  def clear_saved_form(form_id)
    InProgressForm.form_for_user(form_id, current_user)&.destroy if current_user
  end

  private

  attr_reader :current_user

  def block_unknown_hosts
    return if controller_name == 'example'
    raise Common::Exceptions::NotASafeHostError, request.host unless Settings.virtual_hosts.include?(request.host)
  end

  def set_app_info_headers
    headers['X-Git-SHA']           = AppInfo::GIT_REVISION
    headers['X-GitHub-Repository'] = AppInfo::GITHUB_REPO
  end

  def handle_error(error)
    Common::Client::ErrorHandler.handle(error)
  end

  def render_error(exc)
    render json: { errors: exc.errors }, status: exc.status
  end

  # @note Later rescue_from statements take precedence and so we must take care to respect order
  rescue_from StandardError do |error|
    exc = Common::Exceptions::InternalServerError.new(error)
    handle_error(exc)
    render json: { errors: exc.errors }, status: exc.status_code
  end

  rescue_from Common::Exceptions::BaseError do |exc|
    set_empty_auth_header if exc.is_a?(Common::Exceptions::Unauthorized)
    handle_error(exc)
    render json: { errors: exc.errors }, status: exc.status_code
  end

  rescue_from ActionController::ParameterMissing do |error|
    exc = Common::Exceptions::ParameterMissing.new(error.param)
    handle_error(exc)
    render_error(exc)
  end

  rescue_from ActionController::UnknownFormat do |error|
    exc = Common::Exceptions::UnknownFormat.new(error.param)
    handle_error(exc)
    render_error(exc)
  end

  rescue_from Breakers::OutageException do |error|
    exc = Common::Exceptions::ServiceOutage.new(error.outage)
    handle_error(exc)
    render_error(exc)
  end

  rescue_from Common::Client::Errors::ClientError do |_error|
    exc = Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage')
    handle_error(exc)
    render_error(exc)
  end

  rescue_from Pundit::NotAuthorizedError do |_error|
    exc = Common::Exceptions::Forbidden.new(detail: 'User does not have access to the requested resource')
    handle_error(exc)
    render_error(exc)
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
