# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'lighthouse/facilities/client'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      def index
        responses = appointments_service.get_appointments(start_date, end_date)
        va_appointments, facility_ids = va_adapter.parse(responses[:va].body)
        cc_appointments = cc_adapter.parse(responses[:cc].body)

        va_appointments = appointments_with_facilities(va_appointments, facility_ids) if va_appointments.size.positive?

        appointments = (va_appointments + cc_appointments).sort_by(&:start_date_utc)

        render json: Mobile::V0::AppointmentSerializer.new(appointments)
      end

      private

      def appointments_with_facilities(va_appointments, facility_ids)
        facilities = facilities_service.get_facilities(ids: facility_ids.to_a.map { |id| "vha_#{id}" })
        facilities_by_id = facilities.index_by(&:id)
        va_appointments.map do |appointment|
          facility = facilities_by_id["vha_#{appointment.facility_id}"]
          # resources are immutable and are updated with new copies
          appointment.new(
            location: appointment.location.new(
              address: address_from_facility(facility),
              lat: facility.lat,
              long: facility.long
            )
          )
        end
      end

      def address_from_facility(facility)
        address = facility.address['physical']
        return nil unless address

        Mobile::V0::AppointmentAddress.new(
          street: address.slice('address_1', 'address_2', 'address_3').values.compact.join(', '),
          city: address['city'],
          state: address['state'],
          zip_code: address['zip']
        )
      end

      def appointments_service
        Mobile::V0::Appointments::Service.new(@current_user)
      end

      def facilities_service
        Lighthouse::Facilities::Client.new
      end

      def va_adapter
        Mobile::V0::Adapters::VAAppointments.new
      end

      def cc_adapter
        Mobile::V0::Adapters::CommunityCareAppointments.new
      end

      def start_date
        DateTime.parse(params[:start_date])
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start_date', params[:start_date])
      end

      def end_date
        DateTime.parse(params[:end_date])
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end_date', params[:end_date])
      end
    end
  end
end
