# frozen_string_literal: true

class UserSessionForm
  include ActiveModel::Validations
  include SentryLogging

  VALIDATIONS_FAILED_ERROR_CODE = '004'
  SAML_REPLAY_VALID_SESSION_ERROR_CODE = '002'

  ERRORS = { validations_failed: { code: VALIDATIONS_FAILED_ERROR_CODE,
                                   tag: :validations_failed,
                                   short_message: 'on User/Session Validation',
                                   level: :error },
             saml_replay_valid_session: { code: SAML_REPLAY_VALID_SESSION_ERROR_CODE,
                                          tag: :saml_replay_valid_session,
                                          short_message: 'SamlResponse is too late but user has current session',
                                          level: :warn } }.freeze

  attr_reader :user, :user_identity, :session, :saml_uuid

  # rubocop:disable Metrics/MethodLength
  def initialize(saml_response)
    @saml_uuid = saml_response.in_response_to
    saml_user = SAML::User.new(saml_response)
    normalized_attributes = normalize_saml(saml_user)
    existing_user = User.find(normalized_attributes[:uuid])
    @user_identity = UserIdentity.new(normalized_attributes)
    @user = User.new(uuid: @user_identity.attributes[:uuid])
    @user.instance_variable_set(:@identity, @user_identity)
    if saml_user.changing_multifactor?
      if existing_user.present?
        @user.mhv_last_signed_in = existing_user.last_signed_in
        @user.last_signed_in = existing_user.last_signed_in
      else
        @user.last_signed_in = Time.current.utc
        @user.mhv_last_signed_in = Time.current.utc
        log_message_to_sentry(
          "Couldn't locate exiting user after MFA establishment",
          :warn,
          { saml_uuid: normalized_attributes[:uuid], saml_icn: normalized_attributes[:mhv_icn] }
        )
      end
    else
      @user.last_signed_in = Time.current.utc
    end
    @session = Session.new(
      uuid: @user.uuid,
      ssoe_transactionid: saml_user.user_attributes.try(:transactionid)
    )
  end
  # rubocop:enable Metrics/MethodLength

  def normalize_saml(saml_user)
    saml_user.validate!
    saml_user.to_hash
  rescue SAML::UserAttributeError => e
    raise unless e.code == SAML::UserAttributeError::UUID_MISSING_CODE

    idme_uuid, logingov_uuid = uuid_from_account(e&.identifier)
    raise if idme_uuid.blank? && logingov_uuid.blank?

    Rails.logger.info('Account UUID injected into user SAML attributes')
    saml_user.to_hash.merge({ uuid: idme_uuid || logingov_uuid,
                              idme_uuid: idme_uuid,
                              logingov_uuid: logingov_uuid })
  end

  def uuid_from_account(identifier)
    return if identifier.blank?

    matching_accounts = Account.where(icn: identifier)
    Rails.logger.info("[UserSessionForm] Multiple matching accounts for icn:#{identifier}")
    return unless matching_accounts.count == 1

    [matching_accounts.first&.idme_uuid, matching_accounts.first&.logingov_uuid]
  end

  def valid?
    errors.add(:session, :invalid) unless session.valid?
    errors.add(:user, :invalid) unless user.valid?
    errors.add(:user_identity, :invalid) unless @user_identity.valid?
    errors.empty?
  end

  def get_session_errors
    @session.errors.add(:uuid, "can't be blank") if @session.uuid.nil?
    @session.errors&.full_messages
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
    @errors_message ||= "Login Failed! #{errors_hash[:short_message]}" if errors.any?
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
        valid: (@session.valid? && !@session.uuid.nil?),
        errors: get_session_errors
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
    latest_outage = MPI::Configuration.instance.breakers_service.latest_outage
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
