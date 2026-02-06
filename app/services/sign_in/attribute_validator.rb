# frozen_string_literal: true

module SignIn
  class AttributeValidator
    def initialize(user_attributes:)
      @user_attributes = user_attributes
    end

    def perform
      return unless verified_credential?

      validate_credential_attributes

      if mhv_auth?
        validate_mhv_mpi_record
        validate_existing_mpi_attributes
      elsif mpi_record_exists?
        validate_existing_mpi_attributes
        validate_sec_id
        update_mpi_correlation_record
      else
        add_mpi_user
        user_attribute_mismatch_checks(new_record: true)
        validate_existing_mpi_attributes
      end

      verified_icn
    end

    private

    attr_reader :user_attributes

    def validate_existing_mpi_attributes
      check_lock_flag(mpi_response_profile.id_theft_flag, 'Theft Flag', Constants::ErrorCode::MPI_LOCKED_ACCOUNT)
      check_lock_flag(mpi_response_profile.deceased_date, 'Death Flag', Constants::ErrorCode::MPI_LOCKED_ACCOUNT)
      check_id_mismatch(mpi_response_profile.edipis, 'EDIPI', Constants::ErrorCode::MULTIPLE_EDIPI)
      check_id_mismatch(mpi_response_profile.participant_ids, 'CORP_ID', Constants::ErrorCode::MULTIPLE_CORP_ID)
      check_id_mismatch(mpi_response_profile.mhv_iens, 'MHV_ID', Constants::ErrorCode::MULTIPLE_MHV_IEN,
                        raise_error: false)
    end

    def validate_sec_id
      return if sec_id.present?

      sign_in_logger.info('mpi record missing sec_id', icn: verified_icn, pce_status: sec_id_pce_status)
    end

    def add_mpi_user
      add_person_response = mpi_service.add_person_implicit_search(first_name:,
                                                                   last_name:,
                                                                   ssn:,
                                                                   birth_date:,
                                                                   email: credential_email,
                                                                   address:,
                                                                   idme_uuid:,
                                                                   logingov_uuid:)
      unless add_person_response.ok?
        handle_error('User MPI record cannot be created',
                     Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE,
                     error: Errors::MPIUserCreationFailedError)
      end
    end

    def update_mpi_correlation_record
      return if auto_uplevel

      user_attribute_mismatch_checks

      return unless credential_attributes_digest_changed?

      update_profile_response = mpi_service.update_profile(last_name:,
                                                           ssn:,
                                                           birth_date:,
                                                           icn: verified_icn,
                                                           email: credential_email,
                                                           address:,
                                                           idme_uuid:,
                                                           logingov_uuid:,
                                                           edipi:,
                                                           first_name:)
      unless update_profile_response&.ok?
        handle_error('User MPI record cannot be updated', Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE)
      end
    end

    def user_attribute_mismatch_checks(new_record: false)
      attribute_mismatch_check(:first_name, first_name, mpi_response_profile.given_names.first, new_record:)
      attribute_mismatch_check(:last_name, last_name, mpi_response_profile.family_name, new_record:)
      attribute_mismatch_check(:birth_date, birth_date, mpi_response_profile.birth_date, new_record:)
      attribute_mismatch_check(:ssn, ssn, mpi_response_profile.ssn, new_record:, prevent_auth: true)
    end

    def validate_credential_attributes
      if mhv_auth?
        credential_attribute_check(:icn, mhv_icn)
        credential_attribute_check(:mhv_uuid, mhv_credential_uuid)
      else
        credential_attribute_check(:dslogon_uuid, edipi) if dslogon_auth?
        credential_attribute_check(:last_name, last_name) unless auto_uplevel
        credential_attribute_check(:birth_date, birth_date) unless auto_uplevel
      end
      credential_attribute_check(:uuid, logingov_uuid || idme_uuid)
      credential_attribute_check(:email, credential_email)
    end

    def credential_attribute_check(type, credential_attribute)
      return if credential_attribute.present?

      handle_error("Missing attribute in credential: #{type}",
                   Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE,
                   error: Errors::CredentialMissingAttributeError)
    end

    def attribute_mismatch_check(type, credential_attribute, mpi_attribute, new_record: false, prevent_auth: false)
      return unless mpi_attribute

      if scrub_attribute(credential_attribute) != scrub_attribute(mpi_attribute)
        error = prevent_auth ? Errors::AttributeMismatchError : nil

        error_code = type == :ssn ? Constants::ErrorCode::SSN_ATTRIBUTE_MISMATCH : Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE

        handle_error("Attribute mismatch, #{type} in credential does not match MPI attribute",
                     error_code,
                     error:,
                     new_record:)
      end
    end

    def scrub_attribute(attribute)
      attribute.tr('-', '').downcase
    end

    def validate_mhv_mpi_record
      unless mpi_response_profile
        handle_error('No MPI Record for MHV Account',
                     Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE,
                     error: Errors::MHVMissingMPIRecordError)
      end
      attribute_mismatch_check(:icn, mhv_icn, verified_icn)
    end

    def check_lock_flag(attribute, attribute_description, code)
      handle_error("#{attribute_description} Detected", code, error: Errors::MPILockedAccountError) if attribute
    end

    def check_id_mismatch(id_array, id_description, code, raise_error: true)
      if id_array && id_array.compact.uniq.size > 1
        handle_error("User attributes contain multiple distinct #{id_description} values",
                     code,
                     error: Errors::MPIMalformedAccountError, raise_error:)
      end
    end

    def credential_attributes_digest_changed?
      user_verification&.credential_attributes_digest != credential_attributes_digest
    end

    def handle_error(error_message, error_code, error: nil, new_record: nil, raise_error: true)
      sign_in_logger.info('attribute validator error', { errors: error_message,
                                                         code: error_code,
                                                         credential_uuid:,
                                                         mhv_icn:,
                                                         new_record:,
                                                         type: service_name }.compact)
      raise error.new message: error_message, code: error_code if error && raise_error
    end

    def mpi_response_profile
      @mpi_response_profile ||=
        if mhv_credential_uuid
          mpi_service.find_profile_by_identifier(identifier: mhv_credential_uuid,
                                                 identifier_type: MPI::Constants::MHV_UUID)&.profile
        elsif idme_uuid
          mpi_service.find_profile_by_identifier(identifier: idme_uuid,
                                                 identifier_type: MPI::Constants::IDME_UUID)&.profile
        elsif logingov_uuid
          mpi_service.find_profile_by_identifier(identifier: logingov_uuid,
                                                 identifier_type: MPI::Constants::LOGINGOV_UUID)&.profile
        elsif mhv_icn
          mpi_service.find_profile_by_identifier(identifier: mhv_icn, identifier_type: MPI::Constants::ICN)&.profile
        end
    end

    def verified_icn
      @verified_icn ||= mpi_response_profile.icn
    end

    def sec_id
      @sec_id ||= mpi_response_profile.sec_id
    end

    def sec_id_pce_status
      @sec_id_pce_status ||= mpi_response_profile.full_mvi_ids.any? { |id| id.include? '200PROV^USDVA^PCE' }
    end

    def credential_uuid
      @credential_uuid ||= idme_uuid || logingov_uuid
    end

    def mpi_record_exists?
      mpi_response_profile.present?
    end

    def mpi_service
      @mpi_service ||= MPI::Service.new
    end

    def loa
      @loa ||= { current: Constants::Auth::LOA_THREE, highest: Constants::Auth::LOA_THREE }
    end

    def mhv_auth?
      service_name == Constants::Auth::MHV
    end

    def dslogon_auth?
      service_name == Constants::Auth::DSLOGON
    end

    def verified_credential?
      current_ial == Constants::Auth::IAL_TWO
    end

    def user_verification
      @user_verification ||= UserVerification.find_by_type(service_name, user_verification_identifier)
    end

    def idme_uuid                    = user_attributes[:idme_uuid]
    def logingov_uuid                = user_attributes[:logingov_uuid]
    def auto_uplevel                 = user_attributes[:auto_uplevel]
    def current_ial                  = user_attributes[:current_ial]
    def service_name                 = user_attributes[:service_name]
    def first_name                   = user_attributes[:first_name]
    def last_name                    = user_attributes[:last_name]
    def birth_date                   = user_attributes[:birth_date]
    def credential_email             = user_attributes[:csp_email]
    def address                      = user_attributes[:address]
    def ssn                          = user_attributes[:ssn]
    def mhv_icn                      = user_attributes[:mhv_icn]
    def edipi                        = user_attributes[:edipi]
    def mhv_credential_uuid          = user_attributes[:mhv_credential_uuid]
    def credential_attributes_digest = user_attributes[:digest]

    def user_verification_identifier
      case service_name
      when Constants::Auth::MHV      then mhv_credential_uuid
      when Constants::Auth::IDME     then idme_uuid
      when Constants::Auth::DSLOGON  then edipi
      when Constants::Auth::LOGINGOV then logingov_uuid
      end
    end

    def sign_in_logger
      @sign_in_logger = Logger.new(prefix: self.class)
    end
  end
end
