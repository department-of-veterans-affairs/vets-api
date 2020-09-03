# frozen_string_literal: true

require 'ihub/appointments/service'

module V0
  class AppointmentsController < ApplicationController
    def index
      response = service.appointments

      render json: response, serializer: AppointmentSerializer
    end

    private

    def service
      IHub::Appointments::Service.new @current_user
    end
  end
end
