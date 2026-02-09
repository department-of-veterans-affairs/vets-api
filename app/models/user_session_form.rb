# frozen_string_literal: true

class UserSessionForm
  include ActiveModel::Validations

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

  def initialize(saml_response)
    @saml_uuid = saml_response.in_response_to
    saml_user = SAML::User.new(saml_response)
    saml_attributes = normalize_saml(saml_user)
    user_verification = create_user_verification(saml_attributes)
    uuid = user_verification.user_account.id
    existing_user = User.find(uuid)
    @session = Session.new(uuid:, ssoe_transactionid: saml_user.user_attributes.try(:transactionid))
    @user_identity = UserIdentity.new(saml_attributes.merge(uuid:))
    @user = User.new(uuid:)
    @user.session_handle = @session.token
    @user.instance_variable_set(:@identity, @user_identity)
    @user.invalidate_mpi_cache

    if saml_user.changing_multifactor?
      last_signed_in = existing_user&.last_signed_in || Time.current.utc
      @user.mhv_last_signed_in = last_signed_in
      @user.last_signed_in = last_signed_in
      log_existing_user_warning(uuid, saml_attributes[:mhv_icn]) unless existing_user
    else
      @user.last_signed_in = Time.current.utc
    end
  end

  def normalize_saml(saml_user)
    saml_user.validate!
    saml_user_attributes = saml_user.to_hash
    add_csp_id_to_mpi(saml_user_attributes, saml_user_attributes[:idme_uuid]) if saml_user.needs_csp_id_mpi_update?
    saml_user_attributes
  rescue SAML::UserAttributeError => e
    raise unless e.code == SAML::UserAttributeError::UUID_MISSING_CODE

    idme_uuid = uuid_from_account(e&.identifier)
    raise if idme_uuid.blank?

    Rails.logger.info('Account UUID injected into user SAML attributes')
    saml_user_attributes = saml_user.to_hash
    add_csp_id_to_mpi(saml_user_attributes, idme_uuid)
    saml_user_attributes.merge({ uuid: idme_uuid, idme_uuid: })
  end

  def create_user_verification(saml_attributes)
    Login::UserVerifier.new(login_type: saml_attributes[:sign_in]&.dig(:service_name),
                            auth_broker: saml_attributes[:sign_in]&.dig(:auth_broker),
                            mhv_uuid: saml_attributes[:mhv_credential_uuid],
                            idme_uuid: saml_attributes[:idme_uuid],
                            logingov_uuid: saml_attributes[:logingov_uuid],
                            icn: saml_attributes[:icn]).perform
  end

  def add_csp_id_to_mpi(saml_user_attributes, idme_uuid)
    return unless saml_user_attributes[:loa][:current] == LOA::THREE

    Rails.logger.info("[UserSessionForm] Adding CSP ID to MPI, idme: #{idme_uuid}")
    mpi_response = MPI::Service.new.add_person_implicit_search(first_name: saml_user_attributes[:first_name],
                                                               last_name: saml_user_attributes[:last_name],
                                                               ssn: saml_user_attributes[:ssn],
                                                               birth_date: saml_user_attributes[:birth_date],
                                                               idme_uuid:)
    Rails.logger.warn('[UserSessionForm] Failed Add CSP ID to MPI', idme_uuid:) unless mpi_response.ok?
  end

  def uuid_from_account(identifier)
    return if identifier.blank?

    user_account = UserAccount.find_by(icn: identifier)
    return unless user_account

    idme_uuid_array = user_account.user_verifications.map(&:idme_uuid) +
                      user_account.user_verifications.map(&:backing_idme_uuid)

    idme_uuid_array.compact.first
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
        valid: @session.valid? && !@session.uuid.nil?,
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

  private

  def log_existing_user_warning(saml_uuid, saml_icn)
    message = "Couldn't locate existing user after MFA establishment"
    Rails.logger.warn("[UserSessionForm] #{message}", saml_uuid:, saml_icn:)
  end
end
