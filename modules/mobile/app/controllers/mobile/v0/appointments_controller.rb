# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'lighthouse/facilities/client'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      def index
        responses, errors = appointments_service.get_appointments(start_date, end_date)

        va_appointments = []
        cc_appointments = []
        options = {
          meta: {
            errors: nil
          }
        }

        va_appointments = va_appointments_with_facilities(responses[:va].body) unless errors[:va]
        cc_appointments = cc_appointments_adapter.parse(responses[:cc].body) unless errors[:cc]

        appointments = (va_appointments + cc_appointments).sort_by(&:start_date_utc)

        errors = errors.values.compact
        raise Common::Exceptions::BackendServiceException, 'VAOS_502' if errors.size == 2

        options[:meta][:errors] = errors if errors.size.positive?

        render json: Mobile::V0::AppointmentSerializer.new(appointments, options)
      end

      private

      def va_appointments_with_facilities(appointments_from_response)
        appointments, facility_ids = va_appointments_adapter.parse(appointments_from_response)
        appointments_with_facilities(appointments, facility_ids) if appointments.size.positive?
      end

      def appointments_with_facilities(appointments, facility_ids)
        facilities = facilities_service.get_facilities(
          ids: facility_ids.to_a.map { |id| "vha_#{id}" }.join(',')
        )
        va_facilities_adapter.parse(appointments, facilities)
      end

      def appointments_service
        Mobile::V0::Appointments::Service.new(@current_user)
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

      def start_date
        DateTime.parse(params[:startDate])
      rescue ArgumentError, TypeError
        raise Common::Exceptions::InvalidFieldValue.new('startDate', params[:startDate])
      end

      def end_date
        DateTime.parse(params[:endDate])
      rescue ArgumentError, TypeError
        raise Common::Exceptions::InvalidFieldValue.new('endDate', params[:endDate])
      end
    end
  end
end
