# frozen_string_literal: true

require 'common/exceptions'

module VAOS
  module V2
    class AppointmentsController < VAOS::V0::BaseController
      def index
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointments[:data], 'appointments')
        render json: { data: serialized }
      end

      def show
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(appointment, 'appointments')
        render json: { data: serialized }
      end

      def create
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(new_appointment, 'appointments')
        render json: { data: serialized }, status: :created
      end

      def cancel
        resp = appointments_service.cancel_appointment(appt_id: appt_id, reason: cancellation_reason)
        serializer = VAOS::V2::VAOSSerializer.new
        serialized = serializer.serialize(resp, 'appointments')
        render json: { data: serialized }
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

      def cancellation_reason
        params.require(:reason)
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
        params.permit(:kind,
                      :status,
                      :location_id,
                      :clinic,
                      :reason,
                      :service_type,
                      :preferred_language,
                      slot: %i[id start end],
                      contact: [telecom: %i[type value]],
                      requested_periods: %i[start end],
                      practitioner_ids: %i[system value])
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
