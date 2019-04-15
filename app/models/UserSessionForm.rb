# frozen_string_literal: true

class UserSessionForm
  include ActiveModel::Validations

  ERRORS = { validations_failed: { code: '004',
                                   tag: :validations_failed,
                                   short_message: 'on User/Session Validation',
                                   level: :error } }.freeze

  attr_reader :user, :session

  def initialize(saml_response)
    saml_attributes = SAML::User.new(saml_response)
    existing_user = User.find(saml_attributes.user_attributes.uuid)
    @user_identity = UserIdentity.new(saml_attributes.to_hash)
    @user = User.new(uuid: @user_identity.attributes[:uuid])
    @user.instance_variable_set(:@identity, @user_identity)
    if saml_attributes.changing_multifactor?
      @user.mhv_last_signed_in = existing_user.last_signed_in
      @user.last_signed_in = existing_user.last_signed_in
    else
      @user.last_signed_in = Time.current.utc
    end
    @session = Session.new(uuid: @user.uuid)
  end

  def valid?
    errors.add(:session, :invalid) unless session.valid?
    errors.add(:user, :invalid) unless user.valid?
    errors.add(:user_identity, :invalid) unless @user_identity.valid?
    Raven.extra_context(user_session_validation_errors: validation_error_context) unless errors.empty?
    errors.empty?
  end

  def save
    valid? && session.save && user.save && @user_identity.save
  end

  def persist
    if save
      [user, session]
    else
      [nil, nil]
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

  private

  def validation_error_context
    {
      uuid: @user.uuid,
      user:   {
        valid: @user&.valid?,
        errors: @user&.errors&.full_messages
      },
      session:   {
        valid: @session.valid?,
        errors: @session.errors&.full_messages
      },
      identity: {
        valid: @user_identity&.valid?,
        errors: @user_identity&.errors&.full_messages,
        authn_context: @user_identity&.authn_context,
        loa: @user_identity&.loa
      }
    }
  end
end
