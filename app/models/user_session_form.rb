# frozen_string_literal: true

class UserSessionForm
  include ActiveModel::Validations

  ERRORS = { validations_failed: { code: '004',
                                   tag: :validations_failed,
                                   short_message: 'on User/Session Validation',
                                   level: :error },
             saml_replay_valid_session: { code: '002',
                                          tag: :saml_replay_valid_session,
                                          short_message: 'SamlResponse is too late but user has current session',
                                          level: :warn } }.freeze

  attr_reader :user, :user_identity, :session

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

  def errors_message
    @errors_message ||= 'Login Failed! ' + errors_hash[:short_message] if errors.any?
  end

  def errors_hash
    ERRORS[:validations_failed] if errors.any?
  end

  def errors_context
    errors_hash.merge(
      uuid: @user.uuid,
      user: {
        valid: @user&.valid?,
        errors: @user&.errors&.full_messages
      },
      session: {
        valid: @session.valid?,
        errors: @session.errors&.full_messages
      },
      identity: {
        valid: @user_identity&.valid?,
        errors: @user_identity&.errors&.full_messages,
        authn_context: @user_identity&.authn_context,
        loa: @user_identity&.loa
      },
      mvi: mvi_context
    )
  end

  def mvi_context
    latest_outage = MVI::Configuration.instance.breakers_service.latest_outage
    if latest_outage && !latest_outage.ended?
      'breakers is closed for MVI'
    else
      'breakers is open for MVI'
    end
  end

  def error_code
    errors_hash[:code] if errors.any?
  end

  def error_instrumentation_code
    "error:#{errors_hash[:tag]}" if errors.any?
  end
end
