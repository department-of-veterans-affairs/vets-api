# frozen_string_literal: true

module SignIn
  class UserCreator
    include SentryLogging
    attr_reader :state_payload,
                :idme_uuid,
                :logingov_uuid,
                :authn_context,
                :auto_uplevel,
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
      @auto_uplevel = user_attributes[:auto_uplevel]
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
      return unless mpi_response_profile

      check_lock_flag(mpi_response_profile.id_theft_flag, 'Theft Flag', Constants::ErrorCode::MPI_LOCKED_ACCOUNT)
      check_lock_flag(mpi_response_profile.deceased_date, 'Death Flag', Constants::ErrorCode::MPI_LOCKED_ACCOUNT)
      check_id_mismatch(mpi_response_profile.edipis, 'EDIPI', Constants::ErrorCode::MULTIPLE_EDIPI)
      check_id_mismatch(mpi_response_profile.mhv_iens, 'MHV_ID', Constants::ErrorCode::MULTIPLE_MHV_IEN)
      check_id_mismatch(mpi_response_profile.participant_ids, 'CORP_ID', Constants::ErrorCode::MULTIPLE_CORP_ID)
    end

    def update_mpi_record
      return unless user_identity_from_attributes.loa3?

      if mhv_auth?
        set_user_attributes_from_mpi
        add_mpi_user
      elsif mpi_response_profile.present?
        update_mpi_correlation_record
      else
        add_mpi_user
      end
    end

    def add_mpi_user
      add_person_response = mpi_service.add_person_implicit_search(user_identity_from_attributes)
      if add_person_response.ok?
        user_identity_from_attributes.icn = add_person_response.mvi_codes[:icn]
      else
        handle_error('User MPI record cannot be created',
                     Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE,
                     error: Errors::MPIUserCreationFailedError)
      end
    end

    def update_mpi_correlation_record
      return if auto_uplevel

      user_identity_from_attributes.icn ||= mpi_response_profile.icn
      attribute_mismatch_check(:first_name,
                               user_identity_from_attributes.first_name,
                               mpi_response_profile.given_names.first)
      attribute_mismatch_check(:last_name, user_identity_from_attributes.last_name, mpi_response_profile.family_name)
      attribute_mismatch_check(:birth_date, user_identity_from_attributes.birth_date, mpi_response_profile.birth_date)
      attribute_mismatch_check(:ssn, user_identity_from_attributes.ssn, mpi_response_profile.ssn, prevent_auth: true)
      update_profile_response = mpi_service.update_profile(user_identity_from_attributes)
      unless update_profile_response&.ok?
        handle_error('User MPI record cannot be updated', Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE)
      end
    end

    def attribute_mismatch_check(type, credential_attribute, mpi_attribute, prevent_auth: false)
      return unless mpi_attribute

      if scrub_attribute(credential_attribute) != scrub_attribute(mpi_attribute)
        error = prevent_auth ? Errors::AttributeMismatchError : nil
        handle_error("Attribute mismatch, #{type} in credential does not match MPI attribute",
                     Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE,
                     error: error)
      end
    end

    def scrub_attribute(attribute)
      attribute.tr('-', '').downcase
    end

    def log_first_time_user
      unless UserVerification.find_by(user_verification_type => user_verification_identifier)
        sign_in_logger.info("New VA.gov user, type=#{sign_in[:service_name]}")
      end
    end

    def create_authenticated_user
      unless user_verification
        handle_error('User Attributes are Malformed',
                     Constants::ErrorCode::INVALID_REQUEST,
                     error: Errors::UserAttributesMalformedError)
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

    def set_user_attributes_from_mpi
      unless mpi_response_profile
        handle_error('No MPI Record for MHV Account',
                     Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE,
                     error: Errors::MHVMissingMPIRecordError)
      end
      user_identity_from_attributes.first_name = mpi_response_profile.given_names.first
      user_identity_from_attributes.last_name = mpi_response_profile.family_name
      user_identity_from_attributes.birth_date = mpi_response_profile.birth_date
      user_identity_from_attributes.ssn = mpi_response_profile.ssn
      user_identity_from_attributes.icn = mpi_response_profile.icn
      user_identity_from_attributes.mhv_icn = mpi_response_profile.icn
    end

    def user_identity_from_attributes
      @user_identity_from_attributes ||= UserIdentity.new({ idme_uuid: idme_uuid,
                                                            logingov_uuid: logingov_uuid,
                                                            loa: loa,
                                                            sign_in: sign_in,
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
      handle_error("#{attribute_description} Detected", code, error: Errors::MPILockedAccountError) if attribute
    end

    def check_id_mismatch(id_array, id_description, code)
      if id_array && id_array.compact.uniq.size > 1
        handle_error("User attributes contain multiple distinct #{id_description} values",
                     code,
                     error: Errors::MPIMalformedAccountError)
      end
    end

    def handle_error(error_message, error_code, error: nil)
      sign_in_logger.info('user creator error', { errors: error_message })
      raise error, message: error_message, code: error_code if error
    end

    def mpi_response_profile
      mpi_find_profile_response&.profile
    end

    def mpi_find_profile_response
      @mpi_find_profile_response ||= if user_identity_from_attributes.loa3?
                                       mpi_service.find_profile(user_identity_from_attributes)
                                     end
    end

    def mpi_service
      @mpi_service ||= MPI::Service.new
    end

    def user_verification
      @user_verification ||= Login::UserVerifier.new(user_identity_from_attributes).perform
    end

    def user_verification_type
      case sign_in[:service_name]
      when SAML::User::LOGINGOV_CSID
        :logingov_uuid
      when SAML::User::MHV_ORIGINAL_CSID
        :mhv_uuid
      when SAML::User::DSLOGON_CSID
        :dslogon_uuid
      when SAML::User::IDME_CSID
        :idme_uuid
      end
    end

    def user_verification_identifier
      case sign_in[:service_name]
      when SAML::User::LOGINGOV_CSID
        logingov_uuid
      when SAML::User::MHV_ORIGINAL_CSID
        mhv_correlation_id
      when SAML::User::DSLOGON_CSID
        edipi
      when SAML::User::IDME_CSID
        idme_uuid
      end
    end

    def mhv_auth?
      sign_in[:service_name] == SAML::User::MHV_ORIGINAL_CSID
    end

    def user_uuid
      @user_uuid ||= user_verification.backing_credential_identifier
    end

    def login_code
      @login_code ||= SecureRandom.uuid
    end

    def sign_in_logger
      @sign_in_logger = Logger.new(prefix: self.class)
    end
  end
end
