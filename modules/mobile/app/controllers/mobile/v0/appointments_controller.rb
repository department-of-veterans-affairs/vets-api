# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'lighthouse/facilities/client'
require 'mobile/v0/exceptions/validation_errors'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      def index
        appointments, errors = appointments_proxy.get_appointments(start_date, end_date)

        options = {
          meta: {
            errors: errors.size.positive? ? errors : nil
          }
        }

        render json: Mobile::V0::AppointmentSerializer.new(appointments, options)
      end

      def cancel
        validation_result = Mobile::V0::Contracts::CancelAppointment.new.call(cancel_params)
        raise Mobile::V0::Exceptions::ValidationErrors, validation_result if validation_result.failure?

        appointments_proxy.put_cancel_appointment(cancel_params)
        head :no_content
      end
      
      private

      def appointments_proxy
        Mobile::V0::Appointments::Proxy.new(@current_user)
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
        params.permit(:appointmentTime, :clinicId, :facilityId, :healthcareService)
      end
    end
  end
end
