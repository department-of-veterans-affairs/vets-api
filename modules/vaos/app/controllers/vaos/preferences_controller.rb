# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class PreferencesController < ApplicationController
    def index
      response = preferences_service.get_preferences(current_user)
      render json: VAOS::PreferenceSerializer.new(response)
    end

    private

    def preferences_service
      VAOS::PreferencesService.new
    end
  end
end
