# frozen_string_literal: true

module VAOS
  module V2
    class EpsDraftAppointment
      CC_APPOINTMENTS = 'Community Care Appointments'
      REFERRAL_DRAFT_STATIONID_METRIC = 'api.vaos.referral_draft_station_id.access'
      PROVIDER_DRAFT_NETWORK_ID_METRIC = 'api.vaos.provider_draft_network_id.access'

      def initialize(current_user)
        @current_user = current_user
      end

      def call(referral_id, referral_consult_id)
        referral = ccra_referral_service.get_referral(referral_consult_id, @current_user.icn)
        log_referral_metrics(referral)

        return validation_error(referral) unless referral_data_valid?(referral)

        check = appointments_service.referral_appointment_already_exists?(referral_id)
        return usage_error(check) if check[:error] || check[:exists]

        provider = find_provider(referral)
        log_provider_metrics(provider)
        return provider_error(referral) if provider&.id.blank?

        draft = eps_appointment_service.create_draft_appointment(referral_id:)
        return draft_creation_error unless draft.id

        # Bypass drive time calculation if EPS mocks are enabled
        drive_time = fetch_drive_times(provider) unless eps_appointment_service.config.mock_enabled?
        slots = fetch_provider_slots(referral, provider, draft.id)

        success_response(build_draft_response(draft, provider, slots, drive_time))
      rescue Redis::BaseError => e
        redis_error(e)
      rescue => e
        general_error(e)
      end

      private

      # =============================================================================
      # ERROR HANDLING - DRY and reusable error response methods
      # =============================================================================

      def success_response(data)
        { success: true, data: }
      end

      def error_response(json:, status:)
        { success: false, json:, status: }
      end

      def validation_error(referral)
        validation_result = validate_referral_data(referral)
        missing_attributes = validation_result[:missing_attributes]

        error_response(
          json: {
            errors: [{
              title: 'Invalid referral data',
              detail: "Required referral data is missing or incomplete: #{missing_attributes}"
            }]
          },
          status: :unprocessable_entity
        )
      end

      def usage_error(check)
        if check[:error]
          error_response(
            json: {
              errors: [{
                title: 'Appointment creation failed',
                detail: "Error checking existing appointments: #{check[:failures]}"
              }]
            },
            status: :bad_gateway
          )
        else
          error_response(
            json: {
              errors: [{
                title: 'Appointment creation failed',
                detail: 'No new appointment created: referral is already used'
              }]
            },
            status: :unprocessable_entity
          )
        end
      end

      def provider_error(referral)
        log_provider_not_found_error(referral)
        error_response(
          json: {
            errors: [{
              title: 'Appointment creation failed',
              detail: 'Provider not found'
            }]
          },
          status: :not_found
        )
      end

      def draft_creation_error
        error_response(
          json: {
            errors: [{
              title: 'Appointment creation failed',
              detail: 'Could not create draft appointment'
            }]
          },
          status: :unprocessable_entity
        )
      end

      def redis_error(error)
        Rails.logger.error("#{CC_APPOINTMENTS}: #{error.class}}")
        error_response(
          json: {
            errors: [{
              title: 'Appointment creation failed',
              detail: 'Redis connection error'
            }]
          },
          status: :bad_gateway
        )
      end

      def general_error(error)
        Rails.logger.error("#{CC_APPOINTMENTS}: Appointment creation error: #{error.class}")
        original_status = error.respond_to?(:original_status) ? error.original_status : nil
        status_code = appointment_error_status(original_status)

        error_response(
          json: appointment_creation_failed_error(error:, status: original_status),
          status: status_code
        )
      end

      # =============================================================================
      # VALIDATION METHODS
      # =============================================================================

      def referral_data_valid?(referral)
        validate_referral_data(referral)[:valid]
      end

      def validate_referral_data(referral)
        return { valid: false, missing_attributes: 'all required attributes' } if referral.nil?

        required_attributes = {
          'provider_npi' => referral.provider_npi,
          'referral_date' => referral.referral_date,
          'expiration_date' => referral.expiration_date
        }

        missing_attributes = required_attributes.select { |_, value| value.blank? }.keys

        {
          valid: missing_attributes.empty?,
          missing_attributes: missing_attributes.join(', ')
        }
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

      def build_draft_response(draft_appointment, provider, slots, drive_time)
        OpenStruct.new(
          id: draft_appointment.id,
          provider:,
          slots:,
          drive_time:
        )
      end

      def fetch_provider_slots(referral, provider, draft_appointment_id)
        appointment_type_id = get_provider_appointment_type_id(provider)
        eps_provider_service.get_provider_slots(
          provider.id,
          {
            appointmentTypeId: appointment_type_id,
            startOnOrAfter: [Date.parse(referral.referral_date), Date.current].max.to_time(:utc).iso8601,
            startBefore: Date.parse(referral.expiration_date).to_time(:utc).iso8601,
            appointmentId: draft_appointment_id
          }
        )
      rescue ArgumentError
        Rails.logger.error("#{CC_APPOINTMENTS}: Error fetching provider slots")
        nil
      end

      def get_provider_appointment_type_id(provider)
        if provider.appointment_types.blank?
          raise Common::Exceptions::BackendServiceException.new(
            'PROVIDER_APPOINTMENT_TYPES_MISSING',
            {},
            502,
            'Provider appointment types data is not available'
          )
        end

        self_schedulable_types = provider.appointment_types.select { |apt| apt[:is_self_schedulable] == true }

        if self_schedulable_types.blank?
          raise Common::Exceptions::BackendServiceException.new(
            'PROVIDER_SELF_SCHEDULABLE_TYPES_MISSING',
            {},
            502,
            'No self-schedulable appointment types available for this provider'
          )
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
        Rails.logger.error("#{CC_APPOINTMENTS}: Provider not found while creating draft appointment.",
                           { provider_address: referral.treating_facility_address,
                             provider_npi: referral.provider_npi,
                             provider_specialty: referral.provider_specialty,
                             tag: CC_APPOINTMENTS })
      end

      def sanitize_log_value(value)
        return 'no_value' if value.blank?

        value.to_s.gsub(/\s+/, '_')
      end

      # =============================================================================
      # ERROR HANDLING HELPERS (from original controller)
      # =============================================================================

      def appointment_error_status(error_code)
        case error_code
        when 'not-found', 404
          :not_found
        when 'conflict', 409
          :conflict
        when 'bad-request', 400
          :bad_request
        when 'internal-error', 500
          :bad_gateway
        else
          :unprocessable_entity
        end
      end

      def appointment_creation_failed_error(error: nil, title: nil, detail: nil, status: nil)
        default_title = 'Appointment creation failed'
        default_detail = 'Could not create appointment'
        status_code = error.respond_to?(:original_status) ? error.original_status : status

        {
          errors: [{
            title: title || default_title,
            detail: detail || default_detail,
            meta: {
              original_detail: error.try(:response_values)&.dig(:detail),
              original_error: error.try(:message) || 'Unknown error',
              code: status_code,
              backend_response: error.try(:original_body)
            }
          }]
        }
      end

      # =============================================================================
      # SERVICE INITIALIZATION
      # =============================================================================

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