# frozen_string_literal: true
require_relative '../../../../app/services/vaos/appointment_service'

module VAOS
  module V0
    class VAOSController < ApplicationController
      skip_before_action :authenticate

      def get_appointments
        appointments = appointment_service.get_appointments(@current_user)
        render json: AppointmentSerializer.new(appointments).serialized_json
      end

      private

      def appointment_service
        AppointmentService.new
      end
    end
  end
end
