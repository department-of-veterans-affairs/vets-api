# frozen_string_literal: true

module VAOS
  class PreferencesController < VAOS::BaseController
    def index
      response = preferences_service.get_preferences(current_user)
      render json: VAOS::PreferencesSerializer.new(response)
    end

    def update
      response = appointment_requests_service.put_request(id, put_params)
      render json: AppointmentRequestsSerializer.new(response[:data])
    end

    private

    def preferences_service
      VAOS::PreferencesService.new
    end

    def put_params
      params.require()
      params.permit()
    end
  end
end
