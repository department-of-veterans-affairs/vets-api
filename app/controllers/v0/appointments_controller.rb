# frozen_string_literal: true

require 'ihub/appointments/service'

module V0
  class AppointmentsController < ApplicationController
    service_tag 'deprecated'
    def index
      response = service.appointments

      render json: AppointmentSerializer.new(response)
    end

    private

    def service
      IHub::Appointments::Service.new @current_user
    end
  end
end
