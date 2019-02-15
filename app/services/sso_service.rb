# frozen_string_literal: true

require 'saml/auth_fail_handler'
require 'sentry_logging'

class SSOService
  include SentryLogging
  include ActiveModel::Validations
  attr_reader :auth_error_code
  DEFAULT_ERROR_MESSAGE = 'Default generic identity provider error'

  def initialize(response)
    raise 'SAML Response is not a SAML::Response' unless response.is_a?(SAML::Response)
    @saml_response = response

    if saml_response.is_valid?(true)
      @saml_attributes = SAML::User.new(@saml_response)
      @existing_user = User.find(saml_attributes.user_attributes.uuid)
      @new_user_identity = UserIdentity.new(saml_attributes.to_hash)
      @new_user = init_new_user(new_user_identity, existing_user, saml_attributes.changing_multifactor?)
      @new_session = Session.new(uuid: new_user.uuid)
    end
  end

  attr_reader :new_session, :new_user, :new_user_identity, :saml_attributes, :saml_response, :existing_user,
              :failure_instrumentation_tag

  validate :composite_validations

  def persist_authentication!
    existing_user.destroy if new_login?

    if valid?
      if new_login?
        # FIXME: possibly revisit this. Is there a possibility that different sign-in contexts could get
        # merged? MHV LOA1 -> IDME LOA3 is ok, DS Logon LOA1 -> IDME LOA3 is ok, everything else is not.
        # because user, session, user_identity all have the same TTL, this is probably not a problem.
        mergable_identity_attributes.each do |attribute|
          new_user_identity.send(attribute + '=', existing_user.identity.send(attribute))
        end
      end

      return new_session.save && new_user.save && new_user_identity.save
    else
      handle_error_reporting_and_instrumentation
      return false
    end
  end

  def mergable_identity_attributes
    # We don't want to persist the mhv_account_type because then we would have to change it when we
    # upgrade the account to 'Premium' and we want to keep UserIdentity pristine, based on the current
    # signed in session.
    # Also we want the original sign-in, NOT the one from ID.me LOA3
    %w[mhv_correlation_id mhv_icn dslogon_edipi]
  end

  def new_login?
    existing_user.present?
  end

  def authn_context
    if saml_response.decrypted_document
      REXML::XPath.first(saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text ||
        SAML::User::UNKNOWN_AUTHN_CONTEXT
    else
      SAML::User::UNKNOWN_AUTHN_CONTEXT
    end
  end

  private

  def init_new_user(user_identity, existing_user = nil, multifactor_change = false)
    new_user = User.new(uuid: user_identity.attributes[:uuid])
    new_user.instance_variable_set(:@identity, @new_user_identity)
    if multifactor_change
      new_user.mhv_last_signed_in = existing_user.last_signed_in
      new_user.last_signed_in = existing_user.last_signed_in
    else
      new_user.last_signed_in = Time.current.utc
    end
    new_user
  end

  def composite_validations
    if saml_response.is_valid?
      errors.add(:new_session, :invalid) unless new_session.valid?
      errors.add(:new_user, :invalid) unless new_user.valid?
      errors.add(:new_user_identity, :invalid) unless new_user_identity.valid?
    else
      saml_response.errors.each do |error|
        errors.add(:base, error)
      end
    end
  end

  def handle_error_reporting_and_instrumentation
    if errors.keys.include?(:base)
      invalid_saml_response_handler
    else
      invalid_persistence_handler
    end
  end

  def invalid_persistence_handler
    return if new_session.valid? && new_user.valid? && new_user_identity.valid?
    @failure_instrumentation_tag = 'error:validations_failed'
    @auth_error_code = '004' # This could be any of the three failing validation
    log_message_to_sentry('Login Fail! on User/Session Validation', :error, error_context)
  end

  # TODO: Eventually some of this needs to just be instrumentation and not a custom sentry error
  def invalid_saml_response_handler
    return if saml_response.is_valid?
    fail_handler = SAML::AuthFailHandler.new(saml_response)
    if fail_handler.errors?
      @auth_error_code = fail_handler.context[:saml_response][:code]
      @failure_instrumentation_tag = "error:#{fail_handler.error}"
      log_message_to_sentry(fail_handler.message, fail_handler.level, fail_handler.context)
    else
      @auth_error_code = '007'
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
      },
      identity: {
        valid: new_user_identity&.valid?,
        errors: new_user_identity&.errors&.full_messages,
        authn_context: new_user_identity&.authn_context,
        loa: new_user_identity&.loa
      }

    }
  end
end
