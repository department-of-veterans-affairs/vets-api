# frozen_string_literal: true
require_dependency 'vaos/application_controller'

module VAOS
  module V0
    class AppointmentsController < ApplicationController
      def index
        response = va_mobile_service.get_appointments(current_user)
        render json: VAOS::AppointmentSerializer.new(response)
      end
    end
  end
end
