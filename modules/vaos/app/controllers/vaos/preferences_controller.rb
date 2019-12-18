# frozen_string_literal: true

module VAOS
  class PreferencesController < VAOS::BaseController
    def show
      response = preferences_service.get_preferences
      render json: VAOS::PreferencesSerializer.new(response)
    end

    def update
      response = preferences_service.put_preferences(put_params)
      render json: VAOS::PreferencesSerializer.new(response)
    end

    private

    def preferences_service
      VAOS::PreferencesService.new(current_user)
    end

    def put_params
      params.require
      params.permit
    end
  end
end
