# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V2
    class AppointmentsController < VAOS::V0::BaseController
      before_action :validate_params, only: :index

      def index
        render json: VAOS::V2::AppointmentsSerializer.new(appointments[:data], meta: appointments[:meta])
      end

      def update
        resp_appointment = appointments_service.update_appointment(appt_id: appointment_id, status: status)
        render json: VAOS::V2::AppointmentsSerializer.new(resp_appointment)
      end

      private

      def appointments_service
        VAOS::V2::AppointmentsService.new(current_user)
      end

      def appointments
        @appointments ||=
          appointments_service.get_appointments(start_date, end_date, pagination_params)
      end

      def appointment_id
        params.require(:id)
      end

      def status
        params.require(:status)
      end

      def validate_params
        raise Common::Exceptions::ParameterMissing, 'start_date' if params[:start_date].blank?
        raise Common::Exceptions::ParameterMissing, 'end_date' if params[:end_date].blank?
      end

      def start_date
        DateTime.parse(params[:start_date]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start_date', params[:start_date])
      end

      def end_date
        DateTime.parse(params[:end_date]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end_date', params[:end_date])
      end
    end
  end
end
