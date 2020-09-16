# frozen_string_literal: true

module HealthQuest
  module V0
    class AppointmentsController < HealthQuest::V0::BaseController
      before_action :valid_params_present?, only: :index

      def index
        res = serializer.new(appointments[:data], meta: appointments[:meta])
        render json: res
      end

      def show
        apt = appointment_by_id
        render json: HealthQuest::V0::VAAppointmentsSerializer.new(apt[:data], meta: apt[:meta])
      end

      private

      def appointment_by_id
        appointment_service.get_appointment_by_id(params[:id])
      end

      def appointment_service
        HealthQuest::AppointmentService.new(current_user)
      end

      def appointments
        @appointments ||=
          appointment_service.get_appointments(start_date, end_date, pagination_params)
      end

      def serializer
        HealthQuest::V0::VAAppointmentsSerializer
      end

      def valid_params_present?
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
