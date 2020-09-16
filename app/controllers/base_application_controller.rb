# frozen_string_literal: true

require 'feature_flipper'
require 'common/exceptions'
require 'common/client/errors'
require 'saml/settings_service'
require 'sentry_logging'
require 'aes_256_cbc_encryptor'

class BaseApplicationController < ActionController::API
  include SentryLogging
  include Pundit
  include ExceptionHandling
  
  prepend_before_action :block_unknown_hosts, :set_app_info_headers

  attr_reader :current_user
  
  private

  def append_info_to_payload(payload)
    super
    payload[:session] = Session.obscure_token(session[:token]) if session && session[:token]
    payload[:user_uuid] = current_user.uuid if current_user.present?
  end

  # returns a Bad Request if the incoming host header is unsafe.
  def block_unknown_hosts
    return if controller_name == 'example'
    raise Common::Exceptions::NotASafeHostError, request.host unless Settings.virtual_hosts.include?(request.host)
  end

  def set_app_info_headers
    headers['X-Git-SHA'] = AppInfo::GIT_REVISION
    headers['X-GitHub-Repository'] = AppInfo::GITHUB_URL
  end
end
