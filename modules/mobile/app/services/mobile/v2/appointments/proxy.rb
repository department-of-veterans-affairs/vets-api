# frozen_string_literal: true

require 'lighthouse/facilities/client'

module Mobile
  module V2
    module Appointments
      class Proxy
        VAOS_STATUSES = %w[proposed cancelled booked fulfilled arrived].freeze

        def initialize(user)
          @user = user
        end

        def get_appointments(start_date:, end_date:, include_pending:, pagination_params: {})
          statuses = include_pending ? VAOS_STATUSES : VAOS_STATUSES.excluding('proposed')

          # VAOS V2 appointments service accepts pagination params but either it formats them incorrectly
          # or the upstream service does not use them.
          response = vaos_v2_appointments_service.get_appointments(start_date, end_date, statuses.join(','),
                                                                   pagination_params)

          appointments = response[:data]
          filterer = PresentationFilter.new(include_pending:)
          appointments = appointments.keep_if { |appt| filterer.user_facing?(appt) }

          appointments, missing_facilities = merge_clinic_facility_address(appointments)
          appointments, missing_clinics = merge_auxiliary_clinic_info(appointments)
          appointments, missing_providers = merge_provider_names(appointments)

          appointments = vaos_v2_to_v0_appointment_adapter.parse(appointments)
          failures = [
            { appointment_errors: Array.wrap(response[:meta][:failures]) },
            { missing_facilities: },
            { missing_clinics: },
            { missing_providers: }
          ]
          failures.reject! { |failure| failure.values.first&.empty? }

          [appointments.sort_by(&:start_date_utc), failures]
        end

        private

        def merge_clinic_facility_address(appointments)
          cached_facilities = {}

          facility_ids = appointments.map(&:location_id).compact.uniq
          facility_ids.each do |facility_id|
            cached_facilities[facility_id] = appointments_helper.get_facility(facility_id)
          end

          missing_facilities = []

          appointments.each do |appt|
            facility_id = appt[:location_id]
            next unless facility_id

            appt[:location] = cached_facilities[facility_id]

            missing_facilities << facility_id unless cached_facilities[facility_id]
          end

          [appointments, missing_facilities]
        end

        def merge_auxiliary_clinic_info(appointments)
          cached_clinics = {}

          location_clinics = appointments.map { |appt| [appt.location_id, appt.clinic] }.reject { |a| a.any?(nil) }.uniq
          location_clinics.each do |location_id, clinic_id|
            cached_clinics[clinic_id] = appointments_helper.get_clinic(location_id, clinic_id)
          end

          missing_clinics = []

          appointments.each do |appt|
            clinic_id = appt[:clinic]
            next unless clinic_id

            service_name = cached_clinics.dig(clinic_id, :service_name)
            appt[:service_name] = service_name

            physical_location = cached_clinics.dig(clinic_id, :physical_location)
            appt[:physical_location] = physical_location

            missing_clinics << clinic_id unless cached_clinics[clinic_id]
          end
          [appointments, missing_clinics]
        end

        def merge_provider_names(appointments)
          provider_names_proxy = ProviderNames.new(@user)
          missing_providers = []
          appointments.each do |appt|
            practitioners_list = appt[:practitioners]
            next unless practitioners_list

            names, appointment_missing_providers =
              provider_names_proxy.form_names_from_appointment_practitioners_list(practitioners_list)
            appt[:healthcare_provider] = names
            missing_providers.concat(appointment_missing_providers) unless names
          end

          [appointments, missing_providers]
        end

        def appointments_helper
          Mobile::AppointmentsHelper.new(@user)
        end

        def vaos_v2_appointments_service
          VAOS::V2::AppointmentsService.new(@user)
        end

        def vaos_v2_to_v0_appointment_adapter
          Mobile::V0::Adapters::VAOSV2Appointments.new
        end
      end
    end
  end
end
