# frozen_string_literal: true

# VAOS V0 routes and controllers no longer in use
# :nocov:
require 'common/exceptions'

module VAOS
  module V0
    class AvailableAppointmentsController < VAOS::V0::BaseController
      def index
        response = systems_service.get_facility_available_appointments(
          facility_id, start_date, end_date, clinic_ids
        )

        render json: VAOS::V0::AvailabilitySerializer.new(response)
      end

      private

      def systems_service
        VAOS::SystemsService.new(current_user)
      end

      def appt_params
        params.require(%i[facility_id start_date end_date clinic_ids])
        params.permit(
          :facility_id,
          :start_date,
          :end_date,
          clinic_ids: []
        )
      end

      def facility_id
        appt_params[:facility_id]
      end

      def start_date
        DateTime.parse(appt_params[:start_date]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start_date', params[:start_date])
      end

      def end_date
        DateTime.parse(appt_params[:end_date]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end_date', params[:end_date])
      end

      def clinic_ids
        appt_params[:clinic_ids]
      end
    end
  end
end
# :nocov:
