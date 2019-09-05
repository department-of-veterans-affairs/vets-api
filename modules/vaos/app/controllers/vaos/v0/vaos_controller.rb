# frozen_string_literal: true
require_relative '../../../../app/services/vaos/appointment_service'

module VAOS
  module V0
    class VAOSController < ApplicationController
      before_action { authorize :vaos, :access? }

      def get_appointments
        response = appointment_service.get_appointments(@current_user)
        render json: VAOS::AppointmentSerializer.new(response)
      end

      private

      def appointment_service
        AppointmentService.new
      end
    end
  end
end
