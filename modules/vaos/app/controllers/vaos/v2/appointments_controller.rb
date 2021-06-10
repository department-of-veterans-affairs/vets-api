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
        render json: VAOS::V2::AppointmentsSerializer.new(new_appointment), status: :created
      end

      def update
        resp_appointment = appointments_service.update_appointment(appt_id: appt_id, status: status_update)
        render json: VAOS::V2::AppointmentsSerializer.new(resp_appointment)
      end

      private

      def appointments_service
        VAOS::V2::AppointmentsService.new(current_user)
      end

      def appointments
        @appointments ||=
          appointments_service.get_appointments(start_date, end_date, statuses, pagination_params)
      end

      def appointment
        @appointment ||=
          appointments_service.get_appointment(appointment_id)
      end

      def appt_id
        params.require(:id)
      end

      def status_update
        params.require(:status)
      end

      def new_appointment
        @new_appointment ||=
          appointments_service.post_appointment(create_params)
      end

      def appointment_params
        params.require(:start)
        params.require(:end)
        params.permit(:start, :end)
      end

      def create_params
        params.permit(:kind, :status, :location_id, :clinic, :reason, :slot, :contact,
                      :service_type, :requested_periods)
      end

      def start_date
        DateTime.parse(appointment_params[:start]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('start', params[:start])
      end

      def end_date
        DateTime.parse(appointment_params[:end]).in_time_zone
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('end', params[:end])
      end

      def statuses
        s = params[:statuses]
        s.is_a?(Array) ? s.to_csv(row_sep: nil) : s
      end

      def appointment_id
        params[:appointment_id]
      rescue ArgumentError
        raise Common::Exceptions::InvalidFieldValue.new('appointment_id', params[:appointment_id])
      end
    end
  end
end
