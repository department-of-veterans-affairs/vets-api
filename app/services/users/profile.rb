# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/concerns/service_status'
require 'mhv/oh_facilities_helper/service'

module Users
  class Profile
    include Common::Client::Concerns::ServiceStatus

    HTTP_OK = 200
    HTTP_SOME_ERRORS = 296

    attr_reader :user, :scaffold, :oh_facilities_helper

    def initialize(user, session = nil)
      @user = validate!(user)
      @session = session || {}
      @scaffold = Users::Scaffold.new([], HTTP_OK)
      @oh_facilities_helper = MHV::OhFacilitiesHelper::Service.new(user)
    end

    # Fetches and serializes all of the initialized user's profile data that
    # is returned in the '/v0/user' endpoint.
    #
    # If there are no external service errors, the status property is set to 200,
    # and the `errors` property is set to nil.
    #
    # If there *are* errors from any associated external services, the status
    # property is set to 296, and serialized versions of the errors are
    # added to the `errors` array.
    #
    # @return [Struct] A Struct composed of the fetched, serialized profile data.
    #
    def pre_serialize
      fetch_and_serialize_profile
      update_status_and_errors
      scaffold
    end

    private

    def validate!(user)
      raise Common::Exceptions::ParameterMissing.new('user'), 'user' unless user&.class == User

      user
    end

    def fetch_and_serialize_profile
      scaffold.user_account = user_account
      scaffold.profile = profile
      scaffold.vet360_contact_information = vet360_contact_information
      scaffold.va_profile = mpi_profile
      scaffold.veteran_status = veteran_status
      scaffold.in_progress_forms = in_progress_forms
      scaffold.prefills_available = prefills_available
      scaffold.services = services
      scaffold.session = session_data
      scaffold.onboarding = onboarding
    end

    def user_account
      { id: user.user_account_uuid }
    rescue => e
      scaffold.errors << Users::ExceptionHandler.new(e, 'UserAccount').serialize_error
      nil
    end

    # rubocop:disable Metrics/MethodLength
    def profile
      {
        email: user.email,
        first_name: user.first_name,
        middle_name: user.middle_name,
        last_name: user.last_name,
        preferred_name: user.preferred_name,
        birth_date: user.birth_date,
        gender: user.gender,
        zip: user.postal_code,
        last_signed_in: user.last_signed_in,
        loa: user.loa,
        multifactor: user.multifactor,
        verified: user.loa3?,
        sign_in: user.identity.sign_in,
        authn_context: user.authn_context,
        claims:,
        icn: user.icn,
        npi_id: user.npi_id,
        birls_id: user.birls_id,
        edipi: user.edipi,
        sec_id: user.sec_id,
        logingov_uuid: user.logingov_uuid,
        idme_uuid: user.idme_uuid,
        id_theft_flag: user.id_theft_flag,
        initial_sign_in: user.initial_sign_in
      }
    end
    # rubocop:enable Metrics/MethodLength

    def claims
      if Flipper.enabled?(:profile_user_claims, user)
        {
          appeals: AppealsPolicy.new(user).access?,
          coe: CoePolicy.new(user).access?,
          communication_preferences: Vet360Policy.new(user).access? &&
            CommunicationPreferencesPolicy.new(user).access?,
          connected_apps: true,
          medical_copays: MedicalCopaysPolicy.new(user).access?,
          military_history: Vet360Policy.new(user).military_access?,
          payment_history: BGSPolicy.new(user).access?(log_stats: false),
          personal_information: MPIPolicy.new(user).queryable?,
          rating_info: LighthousePolicy.new(user).rating_info_access?,
          **form_526_required_identifiers
        }
      end
    end

    def form_526_required_identifiers
      return {} unless Flipper.enabled?(:form_526_required_identifiers_in_user_object, user)

      { form526_required_identifier_presence: Users::Form526UserIdentifiersStatusService.call(user) }
    end

    def vet360_contact_information
      person = user.vet360_contact_info
      return {} if person.blank?

      email_object = person.email
      {
        vet360_id: user.vet360_id,
        va_profile_id: user.vet360_id,
        email: email_object,
        residential_address: person.residential_address,
        mailing_address: person.mailing_address,
        mobile_phone: person.mobile_phone,
        home_phone: person.home_phone,
        work_phone: person.work_phone,
        temporary_phone: person.temporary_phone,
        fax_number: person.fax_number,
        contact_email_verified: email_object&.contact_email_verified?
      }
    rescue => e
      handle_service_error(e, 'VAProfile', 'vet360_contact_information')
      nil
    end

    # rubocop:disable Metrics/MethodLength
    def mpi_profile
      unless user.loa3?
        error_hash = {
          external_service: 'MVI',
          description: 'User is not LOA3, MPI access denied',
          user_uuid: user.uuid,
          loa: user.loa,
          method: 'mpi_profile'
        }
        log_external_service_error(error_hash)
        return { status: RESPONSE_STATUS[:ok] }
      end

      status = user.mpi_status
      if status == :ok
        migration_schedules = oh_facilities_helper.get_migration_schedules
        user_facility_migrating_to_oh = user_has_migration_schedules?(migration_schedules)
        user_at_pretransitioned_oh_facility = oh_facilities_helper.user_at_pretransitioned_oh_facility?
        user_facility_ready_for_info_alert = oh_facilities_helper.user_facility_ready_for_info_alert?

        {
          status: RESPONSE_STATUS[:ok],
          birth_date: user.birth_date_mpi,
          family_name: user.last_name_mpi,
          gender: user.gender_mpi,
          given_names: user.given_names,
          is_cerner_patient: !user.cerner_id.nil?,
          cerner_id: user.cerner_id,
          cerner_facility_ids: user.cerner_facility_ids,
          facilities: user.va_treatment_facility_ids.map { |id| facility(id) },
          user_at_pretransitioned_oh_facility:,
          user_facility_ready_for_info_alert:,
          oh_migration_info: {
            user_facility_migrating_to_oh:,
            migration_schedules:,
            user_at_pretransitioned_oh_facility:,
            user_facility_ready_for_info_alert:
          },
          va_patient: user.va_patient?,
          mhv_account_state: user.mhv_account_state,
          active_mhv_ids: user.active_mhv_ids,
          scheduling_preferences_pilot_eligible:
        }
      else
        handle_service_error(user.mpi_error, 'MVI', 'mpi_profile')
        nil
      end
    end
    # rubocop:enable Metrics/MethodLength

    def veteran_status
      if user.edipi.blank?
        log_for_missing_edipi

        return build_veteran_status_object(nil, nil)
      end

      build_veteran_status_object(user.veteran?, user.served_in_military?)
    rescue => e
      handle_service_error(e, 'VAProfile', 'veteran_status')
      nil
    end

    def in_progress_forms
      InProgressForm.submission_pending.for_user(user).map do |form|
        {
          form: form.form_id,
          metadata: form.metadata,
          lastUpdated: form.updated_at.to_i
        }
      end
    end

    def prefills_available
      return [] if user.identity.blank?

      FormProfile.prefill_enabled_forms
    end

    def services
      Users::Services.new(user).authorizations
    end

    def update_status_and_errors
      if scaffold.errors.present?
        scaffold.status = HTTP_SOME_ERRORS
      elsif user.edipi.blank? || !user.loa3?
        scaffold.errors = []
      else
        scaffold.errors = nil
      end
    end

    def facility(facility_id)
      cerner_facility_ids = user.cerner_facility_ids || []
      {
        facility_id:,
        is_cerner: cerner_facility_ids.include?(facility_id)
      }
    end

    def session_data
      {
        auth_broker: @user.identity.sign_in[:auth_broker],
        ssoe: @session[:ssoe_transactionid] ? true : false,
        transactionid: @session[:ssoe_transactionid]
      }
    end

    def onboarding
      {
        show: user.show_onboarding_flow_on_login
      }
    end

    def log_external_service_error(error_hash)
      Rails.logger.warn(
        'Users::Profile external service error',
        {
          error: error_hash,
          user_uuid: user.uuid,
          loa: user.loa
        }.to_json
      )
    end

    def log_for_missing_edipi
      Rails.logger.info(
        'Skipping VAProfile veteran status call, No EDIPI present',
        user_uuid: user.uuid,
        loa: user.loa
      )
    end

    def build_veteran_status_object(is_veteran, served_in_military)
      {
        status: RESPONSE_STATUS[:ok],
        is_veteran:,
        served_in_military:
      }
    end

    def handle_service_error(error, service, method_name)
      error_hash = Users::ExceptionHandler.new(error, service).serialize_error
      error_hash[:method] = method_name
      scaffold.errors << error_hash
      log_external_service_error(error_hash)
    end

    def scheduling_preferences_pilot_eligible
      return false unless Flipper.enabled?(:profile_scheduling_preferences, user)

      UserVisnService.new(user).in_pilot_visn?
    rescue => e
      Rails.logger.error("Error checking scheduling preferences pilot eligibility: #{e.message}")
      false
    end

    def user_has_migration_schedules?(schedules)
      schedules.present?
    end
  end
end
