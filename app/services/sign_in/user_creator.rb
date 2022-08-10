# frozen_string_literal: true

module SignIn
  class UserCreator
    include SentryLogging
    attr_reader :state_payload,
                :idme_uuid,
                :logingov_uuid,
                :authn_context,
                :loa,
                :credential_uuid,
                :sign_in,
                :credential_email,
                :multifactor,
                :first_name,
                :last_name,
                :birth_date,
                :ssn,
                :mhv_icn,
                :edipi

    def initialize(user_attributes:, state_payload:)
      @state_payload = state_payload
      @idme_uuid = user_attributes[:idme_uuid]
      @logingov_uuid = user_attributes[:logingov_uuid]
      @authn_context = user_attributes[:authn_context]
      @loa = user_attributes[:loa]
      @credential_uuid = user_attributes[:uuid]
      @sign_in = user_attributes[:sign_in]
      @credential_email = user_attributes[:csp_email]
      @multifactor = user_attributes[:multifactor]
      @first_name = user_attributes[:first_name]
      @last_name = user_attributes[:last_name]
      @birth_date = user_attributes[:birth_date]
      @ssn = user_attributes[:ssn]
      @mhv_icn = user_attributes[:mhv_icn]
      @edipi = user_attributes[:edipi]
    end

    def perform
      validate_mpi_record
      update_mpi_record
      create_authenticated_user
      create_code_container
      user_code_map
    end

    private

    def validate_mpi_record
      check_mpi_lock_flag(user_for_mpi_query.id_theft_flag, 'Theft Flag Detected')
      check_mpi_lock_flag(user_for_mpi_query.deceased_date, 'Death Flag Detected')
      check_id_mismatch(user_for_mpi_query.mpi_edipis, 'EDIPI')
      check_id_mismatch(user_for_mpi_query.mpi_mhv_iens, 'MHV_ID')
      check_id_mismatch(user_for_mpi_query.mpi_participant_ids, 'CORP_ID')
      check_id_mismatch(user_for_mpi_query.mpi_birls_ids, 'BIRLS_ID', raise_error: false)
    end

    def check_mpi_lock_flag(attribute, description)
      if attribute
        log_message_to_sentry(description, 'warn')
        raise SignIn::Errors::MPILockedAccountError, description
      end
    end

    def check_id_mismatch(id_array, id_description, raise_error: true)
      return unless id_array

      if id_array.compact.uniq.size > 1
        log_message = "User attributes contain multiple distinct #{id_description} values"
        log_message_to_sentry(log_message, 'warn')
        raise SignIn::Errors::MPIMalformedAccountError, log_message if raise_error
      end
    end

    def update_mpi_record
      return unless user_for_mpi_query.loa3?

      add_mpi_user if user_for_mpi_query.icn.blank?
      update_mpi_correlation_record unless mhv_auth?
    end

    def add_mpi_user
      mpi_response = user_for_mpi_query.mpi_add_person_implicit_search
      raise SignIn::Errors::MPIUserCreationFailedError, 'User MPI record cannot be created' unless mpi_response.ok?
    end

    def update_mpi_correlation_record
      user_for_mpi_query.identity.icn = user_for_mpi_query.icn
      mpi_response = user_for_mpi_query.mpi_update_profile
      raise SignIn::Errors::MPIUserUpdateFailedError, 'User MPI record cannot be updated' unless mpi_response.ok?
    end

    def create_authenticated_user
      raise SignIn::Errors::UserAttributesMalformedError, 'User Attributes are Malformed' unless user_verification

      user = User.new
      user.instance_variable_set(:@identity, user_identity_from_mpi_query)
      user.uuid = user_uuid
      user_identity_from_mpi_query.uuid = user_uuid
      user.last_signed_in = Time.zone.now
      user.save && user_identity_from_mpi_query.save
    end

    def create_code_container
      SignIn::CodeContainer.new(code: login_code,
                                client_id: state_payload.client_id,
                                code_challenge: state_payload.code_challenge,
                                user_verification_id: user_verification.id,
                                credential_email: credential_email).save!
    end

    def user_identity_from_attributes
      @user_identity_from_attributes ||= UserIdentity.new({ idme_uuid: idme_uuid,
                                                            logingov_uuid: logingov_uuid,
                                                            loa: loa,
                                                            sign_in: sign_in_backing_csp_type,
                                                            first_name: first_name,
                                                            last_name: last_name,
                                                            birth_date: birth_date,
                                                            ssn: ssn,
                                                            edipi: edipi,
                                                            icn: mhv_icn,
                                                            mhv_icn: mhv_icn,
                                                            uuid: credential_uuid })
    end

    def user_identity_from_mpi_query
      @user_identity_from_mpi_query ||= UserIdentity.new({ idme_uuid: idme_uuid,
                                                           logingov_uuid: logingov_uuid,
                                                           loa: loa,
                                                           sign_in: sign_in,
                                                           email: credential_email,
                                                           multifactor: multifactor,
                                                           authn_context: authn_context })
    end

    def user_for_mpi_query
      @user_for_mpi_query ||= begin
        user = User.new
        user.instance_variable_set(:@identity, user_identity_from_attributes)
        user.invalidate_mpi_cache
        user
      end
    end

    def user_code_map
      @user_code_map ||= SignIn::UserCodeMap.new(login_code: login_code,
                                                 type: state_payload.type,
                                                 client_state: state_payload.client_state,
                                                 client_id: state_payload.client_id)
    end

    def user_verification
      @user_verification ||= Login::UserVerifier.new(user_for_mpi_query).perform
    end

    def sign_in_backing_csp_type
      { service_name: service_name_backing_csp_type }
    end

    def service_name_backing_csp_type
      logingov_auth? ? SAML::User::LOGINGOV_CSID : SAML::User::IDME_CSID
    end

    def logingov_auth?
      sign_in[:service_name] == SAML::User::LOGINGOV_CSID
    end

    def mhv_auth?
      sign_in[:service_name] == SAML::User::MHV_ORIGINAL_CSID
    end

    def user_uuid
      @user_uuid ||= user_verification.credential_identifier
    end

    def login_code
      @login_code ||= SecureRandom.uuid
    end
  end
end
