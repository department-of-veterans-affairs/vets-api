# frozen_string_literal: true

module AccreditedRepresentativePortal
  class RepresentativeAttributeValidator
    attr_reader :idme_uuid,
                :logingov_uuid,
                :auto_uplevel,
                :current_ial,
                :service_name,
                :first_name,
                :last_name,
                :birth_date,
                :credential_email,
                :address,
                :ssn,
                :edipi,
                :mhv_correlation_id

    def initialize(user_attributes:)
      @idme_uuid = user_attributes[:idme_uuid]
      @logingov_uuid = user_attributes[:logingov_uuid]
      @auto_uplevel = user_attributes[:auto_uplevel]
      @current_ial = user_attributes[:current_ial]
      @service_name = user_attributes[:service_name]
      @first_name = user_attributes[:first_name]
      @last_name = user_attributes[:last_name]
      @birth_date = user_attributes[:birth_date]
      @credential_email = user_attributes[:csp_email]
      @address = user_attributes[:address]
      @ssn = user_attributes[:ssn]
      @edipi = user_attributes[:edipi]
      @mhv_correlation_id = user_attributes[:mhv_correlation_id]
    end

    def perform
      return unless verified_credential?

      validate_credential_attributes
      validate_representative unless auto_uplevel
      if mpi_record_exists?
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
      check_lock_flag(mpi_response_profile.id_theft_flag, 'Theft Flag',
                      SignIn::Constants::ErrorCode::MPI_LOCKED_ACCOUNT)
      check_lock_flag(mpi_response_profile.deceased_date, 'Death Flag',
                      SignIn::Constants::ErrorCode::MPI_LOCKED_ACCOUNT)
      check_id_mismatch(mpi_response_profile.edipis, 'EDIPI', SignIn::Constants::ErrorCode::MULTIPLE_EDIPI)
      check_id_mismatch(mpi_response_profile.mhv_iens, 'MHV_ID', SignIn::Constants::ErrorCode::MULTIPLE_MHV_IEN)
      check_id_mismatch(mpi_response_profile.participant_ids, 'CORP_ID', SignIn::Constants::ErrorCode::MULTIPLE_CORP_ID)
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
                     SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE,
                     error: SignIn::Errors::MPIUserCreationFailedError)
      end
    end

    def update_mpi_correlation_record
      return if auto_uplevel

      user_attribute_mismatch_checks
      update_profile_response = mpi_service.update_profile(last_name:,
                                                           ssn:,
                                                           birth_date:,
                                                           icn: verified_icn,
                                                           email: credential_email,
                                                           address:,
                                                           idme_uuid:,
                                                           logingov_uuid:,
                                                           first_name:,
                                                           edipi:)
      unless update_profile_response&.ok?
        handle_error('User MPI record cannot be updated', SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE)
      end
    end

    def user_attribute_mismatch_checks
      attribute_mismatch_check(:first_name, first_name, mpi_response_profile.given_names.first)
      attribute_mismatch_check(:last_name, last_name, mpi_response_profile.family_name)
      attribute_mismatch_check(:birth_date, birth_date, mpi_response_profile.birth_date)
      attribute_mismatch_check(:ssn, ssn, mpi_response_profile.ssn, prevent_auth: true)
    end

    def validate_representative
      representative = Veteran::Service::Representative.for_user(first_name:, last_name:, ssn:, dob: birth_date)

      if representative.blank?
        handle_error('User is not a VA representative',
                     SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE,
                     error: Errors::RepresentativeRecordNotFoundError)
      end
    end

    def validate_credential_attributes
      credential_attribute_check(:first_name, first_name) unless auto_uplevel
      credential_attribute_check(:last_name, last_name) unless auto_uplevel
      credential_attribute_check(:birth_date, birth_date) unless auto_uplevel
      credential_attribute_check(:ssn, ssn) unless auto_uplevel

      credential_attribute_check(:uuid, logingov_uuid || idme_uuid)
      credential_attribute_check(:email, credential_email)
    end

    def credential_attribute_check(type, credential_attribute)
      return if credential_attribute.present?

      handle_error("Missing attribute in credential: #{type}",
                   SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE,
                   error: SignIn::Errors::CredentialMissingAttributeError)
    end

    def attribute_mismatch_check(type, credential_attribute, mpi_attribute, prevent_auth: false)
      return unless mpi_attribute

      if scrub_attribute(credential_attribute) != scrub_attribute(mpi_attribute)
        error = prevent_auth ? SignIn::Errors::AttributeMismatchError : nil
        handle_error("Attribute mismatch, #{type} in credential does not match MPI attribute",
                     SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE,
                     error:)
      end
    end

    def scrub_attribute(attribute)
      attribute.tr('-', '').downcase
    end

    def check_lock_flag(attribute, attribute_description, code)
      handle_error("#{attribute_description} Detected", code, error: SignIn::Errors::MPILockedAccountError) if attribute
    end

    def check_id_mismatch(id_array, id_description, code)
      if id_array && id_array.compact.uniq.size > 1
        handle_error("User attributes contain multiple distinct #{id_description} values",
                     code,
                     error: SignIn::Errors::MPIMalformedAccountError)
      end
    end

    def handle_error(error_message, error_code, error: nil)
      sign_in_logger.info('attribute validator error', { errors: error_message,
                                                         credential_uuid:,
                                                         type: service_name })
      raise error.new message: error_message, code: error_code if error
    end

    def mpi_response_profile
      @mpi_response_profile ||=
        if idme_uuid
          mpi_service.find_profile_by_identifier(identifier: idme_uuid,
                                                 identifier_type: MPI::Constants::IDME_UUID)&.profile
        elsif logingov_uuid
          mpi_service.find_profile_by_identifier(identifier: logingov_uuid,
                                                 identifier_type: MPI::Constants::LOGINGOV_UUID)&.profile
        end
    end

    def verified_icn
      @verified_icn ||= mpi_response_profile.icn
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
      @loa ||= { current: SignIn::Constants::Auth::LOA_THREE, highest: SignIn::Constants::Auth::LOA_THREE }
    end

    def verified_credential?
      current_ial == SignIn::Constants::Auth::IAL_TWO
    end

    def sign_in_logger
      @sign_in_logger = SignIn::Logger.new(prefix: self.class)
    end
  end
end
