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
          # or the upstream serice does not use them.
          response = vaos_v2_appointments_service.get_appointments(start_date, end_date, statuses.join(','),
                                                                   pagination_params)

          appointments = response[:data]
          filterer = PresentationFilter.new(include_pending:)
          appointments = appointments.keep_if { |appt| filterer.user_facing?(appt) }

          appointments = merge_clinic_facility_address(appointments)
          appointments = merge_auxiliary_clinic_info(appointments)
          appointments = merge_provider_names(appointments)

          appointments = vaos_v2_to_v0_appointment_adapter.parse(appointments)

          [appointments.sort_by(&:start_date_utc), response[:meta][:failures]]
        end

        private

        def merge_clinic_facility_address(appointments)
          cached_facilities = {}
          appointments.each do |appt|
            facility_id = appt[:location_id]
            next unless facility_id

            cached = cached_facilities[facility_id]
            cached_facilities[facility_id] = get_facility(facility_id) unless cached

            appt[:location] = cached_facilities[facility_id]
          end
        end

        def get_facility(location_id)
          vaos_mobile_facility_service.get_facility(location_id)
        rescue Common::Exceptions::BackendServiceException => e
          Rails.logger.error(
            "Error fetching facility details for location_id #{location_id}",
            location_id:,
            vamf_msg: e.original_body
          )
          nil
        end

        def merge_auxiliary_clinic_info(appointments)
          cached_clinics = {}
          appointments.each do |appt|
            clinic_id = appt[:clinic]
            next unless clinic_id

            cached = cached_clinics[clinic_id]
            cached_clinics[clinic_id] = get_clinic(appt[:location_id], clinic_id) unless cached

            service_name = cached_clinics.dig(clinic_id, :service_name)
            appt[:service_name] = service_name

            physical_location = cached_clinics.dig(clinic_id, :physical_location)
            appt[:physical_location] = physical_location
          end
        end

        def get_clinic(location_id, clinic_id)
          vaos_mobile_facility_service.get_clinic(station_id: location_id, clinic_id:)
        rescue Common::Exceptions::BackendServiceException => e
          Rails.logger.error(
            "Error fetching clinic #{clinic_id} for location #{location_id}",
            clinic_id:,
            location_id:,
            vamf_msg: e.original_body
          )
          nil
        end

        def merge_provider_names(appointments)
          provider_names_proxy = ProviderNames.new(@user)
          appointments.each do |appt|
            practitioners_list = appt[:practitioners]
            names = provider_names_proxy.form_names_from_appointment_practitioners_list(practitioners_list)
            appt[:healthcare_provider] = names
          end
        end

        def vaos_mobile_facility_service
          VAOS::V2::MobileFacilityService.new(@user)
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
