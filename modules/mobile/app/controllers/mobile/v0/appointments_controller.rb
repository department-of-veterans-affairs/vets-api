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

        va_appointments = parse_va_appointments(responses[:va].body) unless errors[:va]
        cc_appointments = cc_adapter.parse(responses[:cc].body) unless errors[:cc]

        # There's currently a bug in the underlying Community Care service
        # where date ranges are not being respected
        cc_appointments.select! do |appointment|
          appointment.start_date_utc.between?(start_date, end_date)
        end

        appointments = (va_appointments + cc_appointments).sort_by(&:start_date_utc)

        errors = errors.values.compact
        raise Common::Exceptions::BackendServiceException, 'VAOS_502' if errors.size == 2

        options[:meta][:errors] = errors if errors.size.positive?

        render json: Mobile::V0::AppointmentSerializer.new(appointments, options)
      end

      private

      def parse_va_appointments(appointments_from_response)
        appointments, facility_ids = va_adapter.parse(appointments_from_response)
        appointments = appointments_with_facilities(appointments, facility_ids) if appointments.size.positive?
        appointments
      end

      def appointments_with_facilities(va_appointments, facility_ids)
        facilities = facilities_service.get_facilities(
          ids: facility_ids.to_a.map { |id| "vha_#{id}" }.join(',')
        )
        facilities_by_id = facilities.index_by(&:id)
        va_appointments.map do |appointment|
          facility = facilities_by_id["vha_#{appointment.facility_id}"]
          # resources are immutable and are updated with new copies
          appointment.new(
            location: appointment.location.new(
              address: address_from_facility(facility),
              phone: phone_from_facility(facility),
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

      def phone_from_facility(facility)
        # captures area code (\d{3}) number \s(\d{3}-\d{4})
        # and extension (until the end of the string) (\S*)\z
        phone_captures = facility.phone['main'].match(/(\d{3})-(\d{3}-\d{4})(\S*)\z/)

        Mobile::V0::AppointmentPhone.new(
          area_code: phone_captures[1].presence,
          number: phone_captures[2].presence,
          extension: phone_captures[3].presence
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
