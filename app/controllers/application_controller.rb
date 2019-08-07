# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'aes_256_cbc_encryptor'

class ApplicationController < ActionController::API
  include AuthenticationAndSSOConcerns
  include Error::ErrorHandler
  include SentryLogging
  include SentryTagging
  include Pundit

  VERSION_STATUS = {
    draft: 'Draft Version',
    current: 'Current Version',
    previous: 'Previous Version',
    deprecated: 'Deprecated Version'
  }.freeze

  prepend_before_action :block_unknown_hosts, :set_app_info_headers
  # Also see AuthenticationAndSSOConcerns for more before filters
  skip_before_action :authenticate, only: %i[cors_preflight routing_error]

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

  # returns a Bad Request if the incoming host header is unsafe.
  def block_unknown_hosts
    return if controller_name == 'example'
    raise Common::Exceptions::NotASafeHostError, request.host unless Settings.virtual_hosts.include?(request.host)
  end

  def set_app_info_headers
    headers['X-GitHub-Repository'] = 'https://github.com/department-of-veterans-affairs/vets-api'
    headers['X-Git-SHA'] = AppInfo::GIT_REVISION
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
    render json: { job_id: jid }, status: 202
  end

  def append_info_to_payload(payload)
    super
    payload[:session] = Session.obscure_token(session[:token]) if session && session[:token]
  end
end
