# frozen_string_literal: true

module VAOS
  class PreferencesController < VAOS::BaseController
    def index
      response = preferences_service.get_preferences(current_user)
      render json: VAOS::PreferencesSerializer.new(response)
    end

    private

    def preferences_service
      VAOS::PreferencesService.new
    end
  end
end
