# frozen_string_literal: true

require 'saml/auth_fail_handler'
require 'sentry_logging'

class SSOService
  include SentryLogging
  include ActiveModel::Validations

  def initialize(saml_response)
    raise 'SAML Response is required' if saml_response.nil?
    @saml_response = saml_response
    @saml_attributes = SAML::User.new(saml_response)
    @existing_user = User.find(saml_attributes.user_attributes.uuid)
    @new_user_identity = UserIdentity.new(saml_attributes.to_hash)
    @new_user = init_new_user(new_user_identity, existing_user, saml_attributes.changing_multifactor?)
    @new_session = Session.new(uuid: new_user.uuid)
  end

  attr_reader :new_session, :new_user, :new_user_identity, :saml_attributes, :saml_response, :existing_user,
              :failure_instrumentation_tag
  # TODO: eventually will rip AuthFailHandler out and make it a custom validator
  validate :composite_validations

  def self.extend_session!(session, user)
    session.expire(Session.redis_namespace_ttl)
    user&.identity&.expire(UserIdentity.redis_namespace_ttl)
    user&.expire(User.redis_namespace_ttl)
  end

  def persist_authentication!
    existing_user.destroy if existing_user.present?
    if valid?
      new_session.save && new_user.save && new_user_identity.save
    else
      handle_error_reporting_and_instrumentation
    end
  end

  private

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

  def composite_validations
    if !saml_response.is_valid?(true)
      errors.add(:saml_response, :invalid)
    else
      errors.add(:new_session, :invalid) unless new_session.valid?
      errors.add(:new_user, :invalid) unless new_user.valid?
      errors.add(:new_user_identity, :invalid) unless new_user_identity.valid?
    end
  end

  def handle_error_reporting_and_instrumentation
    if errors.keys.include?(:saml_response)
      invalid_saml_response_handler
    else
      invalid_persistence_handler
    end
  end

  def invalid_persistence_handler
    return if new_session.valid? && new_user.valid? && new_user_identity.valid?
    @failure_instrumentation_tag = 'error:validations_failed'
    log_message_to_sentry('Login Fail! on User/Session Validation', :error, error_context)
  end

  # TODO: Eventually some of this needs to just be instrumentation and not a custom sentry error
  def invalid_saml_response_handler
    return if saml_response.is_valid?
    fail_handler = SAML::AuthFailHandler.new(saml_response)
    if fail_handler.errors?
      @failure_instrumentation_tag = "error:#{fail_handler.error}"
      log_message_to_sentry(fail_handler.message, fail_handler.level, fail_handler.context)
    else
      @failure_instrumentation_tag = 'error:unknown'
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
