# frozen_string_literal: true

require 'sentry_logging'

class SSOService
  include SentryLogging
  include ActiveModel::Validations

  DEFAULT_ERROR_MESSAGE = 'Default generic identity provider error'
  ERRORS = { validations_failed: { code: '004',
                                   tag: :validations_failed,
                                   short_message: 'on User/Session Validation',
                                   level: :error } }.freeze

  def initialize(response)
    raise 'SAML Response is not a SAML::Response' unless response.is_a?(SAML::Response)
    @saml_response = response
    if saml_response.valid?
      @saml_attributes = SAML::User.new(@saml_response)
      @existing_user = User.find(saml_attributes.user_attributes.uuid)
      @new_user_identity = UserIdentity.new(saml_attributes.to_hash)
      @new_user = init_new_user(new_user_identity, existing_user, saml_attributes.changing_multifactor?)
      @new_session = Session.new(uuid: new_user.uuid)
    end
  end

  attr_reader :new_session, :new_user, :new_user_identity, :saml_attributes, :saml_response, :existing_user,
              :failure_instrumentation_tag, :auth_error_code

  validate :composite_validations

  def persist_authentication!
    existing_user.destroy if new_login?

    if valid?
      return new_session.save && new_user.save && new_user_identity.save
    else
      handle_error_reporting_and_instrumentation
      return false
    end
  end

  def new_login?
    existing_user.present?
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
    if saml_response.valid?
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
    message = 'Login Fail! '
    if saml_response.normalized_errors.present?
      error_hash = saml_response.normalized_errors.first
      error_context = saml_response.normalized_errors
      message += error_hash[:short_message]
      message += ' Multiple SAML Errors' if saml_response.normalized_errors.count > 1
    else
      error_hash = ERRORS[:validations_failed]
      error_context = validation_error_context
      message += error_hash[:short_message]
    end
    @auth_error_code = error_hash[:code]
    @failure_instrumentation_tag = "error:#{error_hash[:tag]}"
    log_message_to_sentry(message, error_hash[:level], error_context)
  end

  def validation_error_context
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
