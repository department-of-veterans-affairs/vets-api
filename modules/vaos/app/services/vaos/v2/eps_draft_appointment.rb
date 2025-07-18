# frozen_string_literal: true

module VAOS
  module V2
    class EpsDraftAppointment
      LOGGER_TAG = 'Community Care Appointments'
      REFERRAL_DRAFT_STATIONID_METRIC = 'api.vaos.referral_draft_station_id.access'
      PROVIDER_DRAFT_NETWORK_ID_METRIC = 'api.vaos.provider_draft_network_id.access'

      attr_reader :id, :provider, :slots, :drive_time, :error

      def initialize(current_user, referral_id, referral_consult_id)
        @current_user = current_user
        @id = nil
        @provider = nil
        @slots = nil
        @drive_time = nil
        @error = nil

        if invalid_parameters?(current_user, referral_id, referral_consult_id)
          set_error('Missing required parameters', :bad_request)
          return
        end

        build_appointment_draft(referral_id, referral_consult_id)
      end

      private

      def build_appointment_draft(referral_id, referral_consult_id)
        referral = get_and_validate_referral(referral_consult_id)
        return if @error

        validate_referral_not_used(referral_id)
        return if @error

        provider = get_and_validate_provider(referral)
        return if @error

        draft = create_draft_appointment(referral_id)
        return if @error

        @drive_time = fetch_drive_times(provider) unless eps_appointment_service.config.mock_enabled?
        @slots = fetch_provider_slots(referral, provider, draft.id)
        @id = draft.id
        @provider = provider
      end

      # =============================================================================
      # ORCHESTRATION METHODS
      # =============================================================================

      def get_and_validate_referral(referral_consult_id)
        referral = ccra_referral_service.get_referral(referral_consult_id, @current_user.icn)
        validation_result = validate_referral_data(referral)

        unless validation_result[:valid]
          return set_error(
            "Required referral data is missing or incomplete: #{validation_result[:missing_attributes]}",
            :unprocessable_entity
          )
        end

        log_referral_metrics(referral)
        referral
      rescue Redis::BaseError => e
        Rails.logger.error("#{LOGGER_TAG}: Redis error - #{e.class}: #{e.message}")
        set_error('Redis connection error', :bad_gateway)
      end

      def validate_referral_not_used(referral_id)
        check = appointments_service.referral_appointment_already_exists?(referral_id)
        if check[:error]
          set_error("Error checking existing appointments: #{check[:failures]}", :bad_gateway)
        elsif check[:exists]
          set_error('No new appointment created: referral is already used', :unprocessable_entity)
        end
      end

      def get_and_validate_provider(referral)
        provider = find_provider(referral)
        if provider&.id.blank?
          log_provider_not_found_error(referral)
          return set_error('Provider not found', :not_found)
        end

        log_provider_metrics(provider)
        provider
      end

      def create_draft_appointment(referral_id)
        draft = eps_appointment_service.create_draft_appointment(referral_id:)
        return set_error('Could not create draft appointment', :unprocessable_entity) if draft.id.blank?

        draft
      end

      # =============================================================================
      # VALIDATION METHODS
      # =============================================================================

      def validate_referral_data(referral)
        return { valid: false, missing_attributes: 'all required attributes' } if referral.nil?

        required_attributes = {
          'provider_npi' => referral.provider_npi,
          'referral_date' => referral.referral_date,
          'expiration_date' => referral.expiration_date
        }

        missing_attributes = required_attributes.select { |_, value| value.blank? }.keys
        return { valid: false, missing_attributes: missing_attributes.join(', ') } unless missing_attributes.empty?

        # Validate date formats
        begin
          Date.parse(referral.referral_date)
          Date.parse(referral.expiration_date)
        rescue ArgumentError
          return { valid: false, missing_attributes: 'invalid date format' }
        end

        { valid: true, missing_attributes: [] }
      end

      # =============================================================================
      # BUSINESS LOGIC METHODS
      # =============================================================================

      def find_provider(referral)
        eps_provider_service.search_provider_services(
          npi: referral.provider_npi,
          specialty: referral.provider_specialty,
          address: referral.treating_facility_address
        )
      end

      def fetch_provider_slots(referral, provider, draft_appointment_id)
        appointment_type_id = get_provider_appointment_type_id(provider)
        return nil if appointment_type_id.nil?

        eps_provider_service.get_provider_slots(
          provider.id,
          {
            appointmentTypeId: appointment_type_id,
            startOnOrAfter: [Date.parse(referral.referral_date), Date.current].max.to_time(:utc).iso8601,
            startBefore: Date.parse(referral.expiration_date).to_time(:utc).iso8601,
            appointmentId: draft_appointment_id
          }
        )
      end

      def get_provider_appointment_type_id(provider)
        # Let external service BackendServiceExceptions bubble up naturally
        if provider.appointment_types.blank?
          Rails.logger.error("#{LOGGER_TAG}: Provider appointment types data is not available")
          return nil
        end

        self_schedulable_types = provider.appointment_types.select { |apt| apt[:is_self_schedulable] == true }

        if self_schedulable_types.blank?
          Rails.logger.error("#{LOGGER_TAG}: No self-schedulable appointment types available for this provider")
          return nil
        end

        self_schedulable_types.first[:id]
      end

      def fetch_drive_times(provider)
        user_address = @current_user.vet360_contact_info&.residential_address
        return nil unless user_address&.latitude && user_address.longitude

        eps_provider_service.get_drive_times(
          destinations: {
            provider.id => {
              latitude: provider.location[:latitude],
              longitude: provider.location[:longitude]
            }
          },
          origin: {
            latitude: user_address.latitude,
            longitude: user_address.longitude
          }
        )
      end

      # =============================================================================
      # LOGGING AND METRICS
      # =============================================================================

      def log_referral_metrics(referral)
        return if referral.nil?

        referring_provider_id = sanitize_log_value(referral.referring_facility_code)
        referral_provider_id = sanitize_log_value(referral.provider_npi)

        StatsD.increment(REFERRAL_DRAFT_STATIONID_METRIC, tags: [
                           'service:community_care_appointments',
                           "referring_provider_id:#{referring_provider_id}",
                           "referral_provider_id:#{referral_provider_id}"
                         ])
      end

      def log_provider_metrics(provider)
        return if provider&.network_ids.blank?

        provider.network_ids.each do |network_id|
          StatsD.increment(PROVIDER_DRAFT_NETWORK_ID_METRIC,
                           tags: ['service:community_care_appointments', "network_id:#{network_id}"])
        end
      end

      def log_provider_not_found_error(referral)
        Rails.logger.error("#{LOGGER_TAG}: Provider not found while creating draft appointment.",
                           { provider_address: referral.treating_facility_address,
                             provider_npi: referral.provider_npi,
                             provider_specialty: referral.provider_specialty,
                             tag: LOGGER_TAG })
      end

      def sanitize_log_value(value)
        return 'no_value' if value.blank?

        value.to_s.gsub(/\s+/, '_')
      end

      # =============================================================================
      # HELPER METHODS & SERVICE INITIALIZATION
      # =============================================================================

      def set_error(message, status)
        @error = { message:, status: }
        nil
      end

      def invalid_parameters?(current_user, referral_id, referral_consult_id)
        current_user.nil? || referral_id.blank? || referral_consult_id.blank? || current_user.icn.blank?
      end

      def ccra_referral_service
        @ccra_referral_service ||= Ccra::ReferralService.new(@current_user)
      end

      def eps_appointment_service
        @eps_appointment_service ||= Eps::AppointmentService.new(@current_user)
      end

      def eps_provider_service
        @eps_provider_service ||= Eps::ProviderService.new(@current_user)
      end

      def appointments_service
        @appointments_service ||= VAOS::V2::AppointmentsService.new(@current_user)
      end
    end
  end
end
