# frozen_string_literal: true

require 'saml/auth_fail_handler'
require 'sentry_logging'

class SSOService
  include SentryLogging

  STATSD_CALLBACK_KEY = 'api.auth.saml_callback'
  STATSD_LOGIN_FAILED_KEY = 'api.auth.login_callback.failed'

  STATSD_CONTEXT_MAP = {
    LOA::MAPPING.invert[1] => 'idme',
    'dslogon' => 'dslogon',
    'myhealthevet' => 'myhealthevet',
    LOA::MAPPING.invert[3] => 'idproof',
    'multifactor' => 'multifactor',
    'dslogon_multifactor' => 'dslogon_multifactor',
    'myhealthevet_multifactor' => 'myhealthevet_multifactor'
  }.freeze

  def initialize(saml_response)
    raise 'SAML Response is required' if saml_response.nil?
    @saml_response = saml_response
    @saml_attributes = SAML::User.new(saml_response)
    @new_user_identity = UserIdentity.new(saml_attributes.to_hash)
    @new_user = init_new_user(new_user_identity, existing_user, saml_attributes.changing_multifactor?)
    @new_session = Session.new(uuid: new_user.uuid)
  end

  attr_reader :new_session, :new_user, :new_user_identity, :saml_attributes, :saml_response

  def self.extend_session!(session, user)
    session.expire(Session.redis_namespace_ttl)
    user&.identity&.expire(UserIdentity.redis_namespace_ttl)
    user&.expire(User.redis_namespace_ttl)
  end

  def existing_user
    @existing_user ||= User.find(saml_attributes.user_attributes.uuid)
  end

  def persist_authentication!
    expire_existing! if existing_user.present?
    return false unless can_persist?
    new_session.save && new_user.save && new_user_identity.save
  end

  def context_key
    STATSD_CONTEXT_MAP[real_authn_context] || 'unknown'
  rescue StandardError
    'unknown'
  end

  private

  def expire_existing!
    existing_user&.identity&.destroy
    existing_user&.destroy
  end

  def init_new_user(user_identity, existing_user = nil, multifactor_change = false)
    new_user = User.new(user_identity.attributes)
    if multifactor_change
      new_user.mhv_last_signed_in = existing_user.last_signed_in
      new_user.last_signed_in = existing_user.last_signed_in
    else
      new_user.last_signed_in = Time.current.utc
    end
    new_user
  end

  def can_persist?
    if saml_response.is_valid?
      if new_session.valid? && new_user.valid? && new_user_identity.valid?
        true
      else
        handle_user_persistence_error
        false
      end
    else
      handle_saml_response_error
      false
    end
  end

  def handle_user_persistence_error
    StatsD.increment(STATSD_LOGIN_FAILED_KEY, tags: ['error:validations_failed'])
    log_message_to_sentry('Login Fail! on User/Session Validation', :error, error_context)
  end

  def handle_saml_response_error
    fail_handler = SAML::AuthFailHandler.new(saml_response)
    StatsD.increment(STATSD_CALLBACK_KEY, tags: ['status:failure', "context:#{context_key}"])
    if fail_handler.errors?
      StatsD.increment(STATSD_LOGIN_FAILED_KEY, tags: ["error:#{fail_handler.error}"])
      log_message_to_sentry(fail_handler.message, fail_handler.level, fail_handler.context)
    else
      StatsD.increment(STATSD_LOGIN_FAILED_KEY, tags: ['error:validations_failed'])
      log_message_to_sentry('Unknown SAML Login Error', :error, error_context)
    end
  end

  def error_context
    {
      uuid: new_user.uuid,
      user:   {
        valid: new_user&.valid?,
        errors: new_user&.errors&.full_messages
      },
      session:   {
        valid: new_session&.valid?,
        errors: new_session&.errors&.full_messages
      }
    }
  end

  def real_authn_context
    REXML::XPath.first(saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text
  end
end
