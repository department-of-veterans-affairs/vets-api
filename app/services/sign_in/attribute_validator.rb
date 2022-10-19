# frozen_string_literal: true

module SignIn
  class AttributeValidator
    attr_reader :idme_uuid,
                :logingov_uuid,
                :auto_uplevel,
                :loa,
                :credential_uuid,
                :sign_in,
                :first_name,
                :last_name,
                :birth_date,
                :ssn,
                :mhv_icn,
                :edipi,
                :mhv_correlation_id

    def initialize(user_attributes:)
      @idme_uuid = user_attributes[:idme_uuid]
      @logingov_uuid = user_attributes[:logingov_uuid]
      @auto_uplevel = user_attributes[:auto_uplevel]
      @loa = user_attributes[:loa]
      @credential_uuid = user_attributes[:uuid]
      @sign_in = user_attributes[:sign_in]
      @first_name = user_attributes[:first_name]
      @last_name = user_attributes[:last_name]
      @birth_date = user_attributes[:birth_date]
      @ssn = user_attributes[:ssn]
      @mhv_icn = user_attributes[:mhv_icn]
      @edipi = user_attributes[:edipi]
      @mhv_correlation_id = user_attributes[:mhv_correlation_id]
    end

    def perform
      return unless verified_credential?

      if mhv_auth?
        mhv_set_user_attributes_from_mpi
        add_mpi_user
        validate_existing_mpi_attributes
      elsif mpi_record_exists?
        validate_existing_mpi_attributes
        update_mpi_correlation_record
      else
        add_mpi_user
        validate_existing_mpi_attributes
      end

      verified_icn
    end

    private

    def validate_existing_mpi_attributes
      check_lock_flag(mpi_response_profile.id_theft_flag, 'Theft Flag', Constants::ErrorCode::MPI_LOCKED_ACCOUNT)
      check_lock_flag(mpi_response_profile.deceased_date, 'Death Flag', Constants::ErrorCode::MPI_LOCKED_ACCOUNT)
      check_id_mismatch(mpi_response_profile.edipis, 'EDIPI', Constants::ErrorCode::MULTIPLE_EDIPI)
      check_id_mismatch(mpi_response_profile.mhv_iens, 'MHV_ID', Constants::ErrorCode::MULTIPLE_MHV_IEN)
      check_id_mismatch(mpi_response_profile.participant_ids, 'CORP_ID', Constants::ErrorCode::MULTIPLE_CORP_ID)
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
      attribute_mismatch_check(:first_name, first_name, mpi_response_profile.given_names.first)
      attribute_mismatch_check(:last_name, last_name, mpi_response_profile.family_name)
      attribute_mismatch_check(:birth_date, birth_date, mpi_response_profile.birth_date)
      attribute_mismatch_check(:ssn, ssn, mpi_response_profile.ssn, prevent_auth: true)
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

    def mhv_set_user_attributes_from_mpi
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
                                                            icn: mhv_icn,
                                                            mhv_icn: mhv_icn,
                                                            mhv_correlation_id: mhv_correlation_id,
                                                            uuid: credential_uuid })
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
      @mpi_response_profile ||= mpi_service.find_profile(user_identity_for_mpi_query)&.profile
    end

    def user_identity_for_mpi_query
      @user_identity_for_mpi_query ||= UserIdentity.new({ idme_uuid: idme_uuid,
                                                          logingov_uuid: logingov_uuid,
                                                          loa: loa,
                                                          mhv_icn: mhv_icn,
                                                          uuid: credential_uuid })
    end

    def verified_icn
      @verified_icn ||= mpi_response_profile.icn
    end

    def mpi_record_exists?
      mpi_response_profile.present?
    end

    def mpi_service
      @mpi_service ||= MPI::Service.new
    end

    def mhv_auth?
      sign_in[:service_name] == SAML::User::MHV_ORIGINAL_CSID
    end

    def verified_credential?
      loa[:current] == LOA::THREE
    end

    def sign_in_logger
      @sign_in_logger = Logger.new(prefix: self.class)
    end
  end
end
