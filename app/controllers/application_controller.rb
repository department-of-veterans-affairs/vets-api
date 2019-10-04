# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'aes_256_cbc_encryptor'

class ApplicationController < ActionController::API
  include AuthenticationAndSSOConcerns
  include ErrorHandler
  include SentryLogging
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
  before_action :set_tags_and_extra_context

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

  def set_tags_and_extra_context
    Thread.current['request_id'] = request.uuid
    Thread.current['additional_request_attributes'] = {
      'remote_ip' => request.remote_ip,
      'user_agent' => request.user_agent
    }
    Raven.extra_context(request_uuid: request.uuid)
    Raven.user_context(user_context) if current_user
    Raven.tags_context(tags_context)
  end

  def user_context
    {
      uuid: current_user&.uuid,
      authn_context: current_user&.authn_context,
      loa: current_user&.loa,
      mhv_icn: current_user&.mhv_icn
    }
  end

  def tags_context
    { controller_name: controller_name }.tap do |tags|
      if current_user.present?
        tags[:sign_in_method] = current_user.identity.sign_in[:service_name]
        # account_type is filtered by sentry, becasue in other contexts it refers to a bank account type
        tags[:sign_in_acct_type] = current_user.identity.sign_in[:account_type]
      else
        tags[:sign_in_method] = 'not-signed-in'
      end
    end
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
    render json: { job_id: jid }, status: :accepted
  end

  def append_info_to_payload(payload)
    super
    payload[:session] = Session.obscure_token(session[:token]) if session && session[:token]
    payload[:user_uuid] = current_user.uuid if current_user.present?
  end
end
