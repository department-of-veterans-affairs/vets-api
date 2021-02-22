# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'lighthouse/facilities/client'
require 'mobile/v0/exceptions/validation_errors'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      def index
        use_cache = params[:useCache] || false
        validated_params = Mobile::V0::Contracts::GetAppointments.new.call(
          start_date: params[:startDate],
          end_date: params[:endDate],
          use_cache: use_cache
        )

        raise Mobile::V0::Exceptions::ValidationErrors, validated_params if validated_params.failure?

        appointments, errors = appointments_proxy.get_appointments(validated_params.to_h)

        options = {
          meta: {
            errors: errors.size.positive? ? errors : nil
          }
        }

        render json: Mobile::V0::AppointmentSerializer.new(appointments, options)
      end

      def cancel
        decoded_cancel_params = Mobile::V0::Contracts::CancelAppointment.decode_cancel_id(params[:id])
        contract = Mobile::V0::Contracts::CancelAppointment.new.call(decoded_cancel_params)
        raise Mobile::V0::Exceptions::ValidationErrors, contract if contract.failure?

        appointments_proxy.put_cancel_appointment(decoded_cancel_params)
        head :no_content
      end

      private

      def appointments_proxy
        Mobile::V0::Appointments::Proxy.new(@current_user)
      end
    end
  end
end
