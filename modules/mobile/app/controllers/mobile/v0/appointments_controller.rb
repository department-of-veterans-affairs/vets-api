# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'lighthouse/facilities/client'
require 'mobile/v0/exceptions/validation_errors'

module Mobile
  module V0
    class AppointmentsController < ApplicationController
      def index
        use_cache = params[:useCache] || false
        start_date = params[:startDate] || (DateTime.now.utc.beginning_of_day - 3.months).iso8601
        end_date = params[:endDate] || (DateTime.now.utc.beginning_of_day + 6.months).iso8601

        validated_params = Mobile::V0::Contracts::GetAppointments.new.call(
          start_date: start_date,
          end_date: end_date,
          use_cache: use_cache
        )

        raise Mobile::V0::Exceptions::ValidationErrors, validated_params if validated_params.failure?

        render json: fetch_cached_or_service(validated_params)
      end

      def cancel
        decoded_cancel_params = Mobile::V0::Contracts::CancelAppointment.decode_cancel_id(params[:id])
        contract = Mobile::V0::Contracts::CancelAppointment.new.call(decoded_cancel_params)
        raise Mobile::V0::Exceptions::ValidationErrors, contract if contract.failure?

        appointments_proxy.put_cancel_appointment(decoded_cancel_params)
        head :no_content
      end

      private

      def fetch_cached_or_service(validated_params)
        json = Mobile::V0::Appointment.get_cached_appointments(@current_user) if validated_params[:use_cache]

        # if JSON has been retrieved from redis, delete the cached version and return recovered appointments
        # otherwise fetch appointments from the upstream service
        if json
          Rails.logger.info('mobile appointments cache fetch', user_uuid: @current_user.uuid)
          Mobile::V0::Appointment.delete_cached_appointments(@current_user)
          json
        else
          Rails.logger.info('mobile appointments service fetch', user_uuid: @current_user.uuid)
          appointments, errors = appointments_proxy.get_appointments(validated_params.to_h)
          options = {
            meta: {
              errors: errors.size.positive? ? errors : nil
            }
          }

          Mobile::V0::AppointmentSerializer.new(appointments, options)
        end
      end

      def appointments_proxy
        Mobile::V0::Appointments::Proxy.new(@current_user)
      end
    end
  end
end
