# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class VAFacilities
        def map_appointments_to_facilities(appointments, facilities)
          facilities_by_id = map_facilities_id(facilities)

          appointments.map do |appointment|
            facility = facilities_by_id&.dig("vha_#{appointment.id_for_address}")
            if facility
              # resources are immutable and are updated with new copies
              appointment.new(
                location: appointment.location.new(
                  name: facility.name,
                  address: Mobile::FacilitiesHelper.address_from_facility(facility),
                  phone: Mobile::FacilitiesHelper.phone_from_facility(facility),
                  lat: facility.lat,
                  long: facility.long
                )
              )
            elsif appointment.appointment_type == VAAppointments::APPOINTMENT_TYPES[:va_video_connect_home]
              appointment.new(location: Mobile::FacilitiesHelper.blank_location(appointment))
            else
              log_missing_facility(appointment)
              raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error'
            end
          end
        end

        private

        def map_facilities_id(facilities)
          facilities&.map do |facility|
            next if facility.id.nil?

            facility.id = "vha_#{facility.id.delete('vha_')}"
          end
          facilities&.index_by(&:id)
        end

        def log_missing_facility(appointment)
          Rails.logger.warn(
            'Could not find matching facility for mobile appointment',
            {
              appointment_id: appointment.id,
              facility_id: appointment.facility_id,
              sta6aid: appointment.sta6aid,
              id_for_address: appointment.id_for_address,
              type: appointment.appointment_type,
              location: appointment.location,
              status: appointment.status,
              healthcare_service: appointment.healthcare_service
            }
          )
        end
      end
    end
  end
end
