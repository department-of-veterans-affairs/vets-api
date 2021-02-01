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
      
      def cancel
        cancel_reasons = get_facility_cancel_reasons(cancel_params[:facility_id])
        cancel_reason = nil
        
        if cancel_reasons.include?
          cancel_reason = Mobile::V0::AppointmentCancelReason::UNABLE_TO_KEEP_APPT
        end
        
        if (
          cancelReasons.some(reason => reason.number === UNABLE_TO_KEEP_APPT)
        ) {
          cancelReason = UNABLE_TO_KEEP_APPT;
        await updateAppointment({
          ...cancelData,
          cancelReason,
        });
        } else if (
          cancelReasons.some(reason => VALID_CANCEL_CODES.has(reason.number))
        ) {
          cancelReason = cancelReasons.find(reason =>
            VALID_CANCEL_CODES.has(reason.number),
          );
        await updateAppointment({
          ...cancelData,
          cancelReason: cancelReason.number,
        });
        } else {
          throw new Error('Unable to find valid cancel reason');
        }
        
        binding.pry
        params = cancel_params.merge({ cancel_reason: '5', cancel_code: 'PC' })
        appointments_service.put_cancel_appointment(params)
        head :no_content
      end

      private

      def va_appointments_with_facilities(appointments_from_response)
        appointments, facility_ids = va_appointments_adapter.parse(appointments_from_response)
        get_appointment_facilities(appointments, facility_ids) if appointments.size.positive?
      end

      def get_appointment_facilities(appointments, facility_ids)
        facilities = facilities_service.get_facilities(
          ids: facility_ids.to_a.map { |id| "vha_#{id}" }.join(',')
        )
        va_facilities_adapter.map_appointments_to_facilities(appointments, facilities)
      end
      
      def get_facility_cancel_reasons(facility_id)
        appointments_service.get_cancel_reasons(facility_id).map do |reason|
          Mobile::V0::AppointmentCancelReason.new(reason)
        end
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

      def cancel_params
        params.permit(:appointment_time, :clinic_id, :facility_id, :cancel_reason, :cancel_code, :remarks, :clinic_name)
      end
    end
  end
end
