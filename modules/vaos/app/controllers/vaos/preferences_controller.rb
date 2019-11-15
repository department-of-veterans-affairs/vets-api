# frozen_string_literal: true

require_dependency 'vaos/application_controller'

module VAOS
  class PreferencesController < ApplicationController
    def index
      response = preference_service.get_preferences(current_user)
      render json: VAOS::PreferenceSerializer.new(response)
    end

    private

    def preference_service
      VAOS::PreferenceService.new
    end
  end
end
