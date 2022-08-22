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
                :edipi,
                :mhv_correlation_id

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
      @mhv_correlation_id = user_attributes[:mhv_correlation_id]
    end

    def perform
      validate_mpi_record
      update_mpi_record
      log_first_time_user
      create_authenticated_user
      create_code_container
      user_code_map
    end

    private

    def validate_mpi_record
      return unless mpi_find_profile_response

      check_lock_flag(mpi_find_profile_response.id_theft_flag, 'Theft Flag', Constants::ErrorCode::MPI_LOCKED_ACCOUNT)
      check_lock_flag(mpi_find_profile_response.deceased_date, 'Death Flag', Constants::ErrorCode::MPI_LOCKED_ACCOUNT)
      check_id_mismatch(mpi_find_profile_response.edipis, 'EDIPI', Constants::ErrorCode::MULTIPLE_EDIPI)
      check_id_mismatch(mpi_find_profile_response.mhv_iens, 'MHV_ID', Constants::ErrorCode::MULTIPLE_MHV_IEN)
      check_id_mismatch(mpi_find_profile_response.participant_ids, 'CORP_ID', Constants::ErrorCode::MULTIPLE_CORP_ID)
    end

    def update_mpi_record
      return unless user_identity_from_attributes.loa3?

      add_mpi_user unless mpi_find_profile_response
      update_mpi_correlation_record unless mhv_auth?
    end

    def add_mpi_user
      add_person_response = mpi_service.add_person_implicit_search(user_identity_from_attributes)
      if add_person_response.ok?
        user_identity_from_attributes.icn = add_person_response.mvi_codes[:icn]
      else
        handle_error(Errors::MPIUserCreationFailedError,
                     'User MPI record cannot be created',
                     Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE)
      end
    end

    def update_mpi_correlation_record
      user_identity_from_attributes.icn ||= mpi_find_profile_response.icn
      update_profile_response = mpi_service.update_profile(user_identity_from_attributes)
      unless update_profile_response.ok?
        handle_error(Errors::MPIUserUpdateFailedError,
                     'User MPI record cannot be updated',
                     Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE)
      end
    end

    def log_first_time_user
      user_verification_type = logingov_auth? ? :logingov_uuid : :idme_uuid
      user_verification_identifier = logingov_auth? ? logingov_uuid : idme_uuid
      unless UserVerification.find_by(user_verification_type => user_verification_identifier)
        sign_in_logger.info("New VA.gov user, type=#{sign_in[:service_name]}")
      end
    end

    def create_authenticated_user
      unless user_verification
        handle_error(Errors::UserAttributesMalformedError,
                     'User Attributes are Malformed',
                     Constants::ErrorCode::INVALID_REQUEST)
      end

      user = User.new
      user.instance_variable_set(:@identity, user_identity_for_user_creation)
      user.uuid = user_uuid
      user_identity_for_user_creation.uuid = user_uuid
      user.last_signed_in = Time.zone.now
      user.save && user_identity_for_user_creation.save
    end

    def create_code_container
      CodeContainer.new(code: login_code,
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
                                                            mhv_correlation_id: mhv_correlation_id,
                                                            icn: mhv_icn,
                                                            mhv_icn: mhv_icn,
                                                            uuid: credential_uuid })
    end

    def user_identity_for_user_creation
      @user_identity_for_user_creation ||= UserIdentity.new({ idme_uuid: idme_uuid,
                                                              logingov_uuid: logingov_uuid,
                                                              loa: loa,
                                                              sign_in: sign_in,
                                                              email: credential_email,
                                                              multifactor: multifactor,
                                                              authn_context: authn_context })
    end

    def user_code_map
      @user_code_map ||= UserCodeMap.new(login_code: login_code,
                                         type: state_payload.type,
                                         client_state: state_payload.client_state,
                                         client_id: state_payload.client_id)
    end

    def check_lock_flag(attribute, attribute_description, code)
      handle_error(Errors::MPILockedAccountError, "#{attribute_description} Detected", code) if attribute
    end

    def check_id_mismatch(id_array, id_description, code)
      if id_array && id_array.compact.uniq.size > 1
        handle_error(Errors::MPIMalformedAccountError,
                     "User attributes contain multiple distinct #{id_description} values",
                     code)
      end
    end

    def handle_error(error, error_message, error_code)
      log_message_to_sentry(error_message, 'warn')
      raise error, message: error_message, code: error_code
    end

    def mpi_find_profile_response
      @mpi_find_profile_response ||= if user_identity_from_attributes.loa3?
                                       mpi_service.find_profile(user_identity_from_attributes).profile
                                     end
    end

    def mpi_service
      @mpi_service ||= MPI::Service.new
    end

    def user_verification
      @user_verification ||= Login::UserVerifier.new(user_identity_from_attributes).perform
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

    def sign_in_logger
      @sign_in_logger = SignIn::Logger.new(prefix: self.class)
    end
  end
end
