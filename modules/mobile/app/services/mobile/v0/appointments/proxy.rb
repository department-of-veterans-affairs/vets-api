# frozen_string_literal: true

module Mobile
  module V0
    module Appointments
      class Proxy
        def initialize(user)
          @user = user
        end

        def get_appointments(start_date, end_date)
          responses, errors = parallel_appointments_service.get_appointments(start_date, end_date)

          va_appointments = []
          cc_appointments = []

          va_appointments = va_appointments_with_facilities(responses[:va].body) unless errors[:va]
          cc_appointments = cc_appointments_adapter.parse(responses[:cc].body) unless errors[:cc]

          # There's currently a bug in the underlying Community Care service
          # where date ranges are not being respected
          cc_appointments.select! do |appointment|
            appointment.start_date_utc.between?(start_date, end_date)
          end

          appointments = (va_appointments + cc_appointments).sort_by(&:start_date_utc)

          errors = errors.values.compact
          raise Common::Exceptions::BackendServiceException, 'MOBL_502_upstream_error' if errors.size == 2

          [appointments, errors]
        end

        private

        def va_appointments_with_facilities(appointments_from_response)
          appointments, facility_ids = va_appointments_adapter.parse(appointments_from_response)
          return [] if appointments.nil?

          get_appointment_facilities(appointments, facility_ids) if appointments.size.positive?
        end

        def get_appointment_facilities(appointments, facility_ids)
          facilities = facilities_service.get_facilities(
            ids: facility_ids.to_a.map { |id| "vha_#{id}" }.join(',')
          )
          va_facilities_adapter.map_appointments_to_facilities(appointments, facilities)
        end

        def parallel_appointments_service
          Mobile::V0::Appointments::Service.new(@user)
        end

        def facilities_service
          Lighthouse::Facilities::Client.new
        end

        def va_appointments_adapter
          Mobile::V0::Adapters::VAAppointments.new
        end

        def va_facilities_adapter
          Mobile::V0::Adapters::VAFacilities.new
        end

        def cc_appointments_adapter
          Mobile::V0::Adapters::CommunityCareAppointments.new
        end
      end
    end
  end
end
