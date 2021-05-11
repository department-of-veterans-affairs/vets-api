# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V2
    class AppointmentsController < VAOS::V0::BaseController
      def index
        render json: VAOS::V2::AppointmentsSerializer.new(appointments[:data], meta: appointments[:meta])
      end

      def show
        render json: VAOS::V2::AppointmentsSerializer.new(appointment)
      end
      
      def create
        new_appointment = appointments_service.post_appointments(create_params)
        render json: VAOS::V2::AppointmentsSerializer.new(new_appointment)
      end

      private

      def appointments_service
        VAOS::V2::AppointmentsService.new(current_user)
      end

      def appointments
        @appointments ||=
          appointments_service.get_appointments(start_date, end_date, pagination_params)
      end

      def appointment
        @appointment ||=
          appointments_service.get_appointment(appointment_id)
      end

      def appointment_params
        params.require(:start_date)
        params.require(:end_date)
        params
      end

      def create_params
        params.permit(:kind, :status, :location_id, :clinic, :reason, :slot, :contact,
                      :service_type, :requested_periods)
      end

      def start_date
        DateTime.parse(appointment_params[:start_date]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start_date', params[:start_date])
      end

      def end_date
        DateTime.parse(appointment_params[:end_date]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end_date', params[:end_date])
      end

      def appointment_id
        params[:appointment_id]
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('appointment_id', params[:appointment_id])
      end
    end
  end
end
