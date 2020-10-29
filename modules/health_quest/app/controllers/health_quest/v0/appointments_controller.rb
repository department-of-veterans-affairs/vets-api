# frozen_string_literal: true

module HealthQuest
  module V0
    class AppointmentsController < HealthQuest::V0::BaseController
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
    end
  end
end
