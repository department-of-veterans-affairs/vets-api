# frozen_string_literal: true

module V0
  class PreferencesController < ApplicationController
    before_action :set_preference, only: :show

    def index
      results = Preference.all
      render json: results.to_a, serializer: PreferencesSerializer
    end

    def show
      render json: @preference, serializer: PreferenceSerializer
    end

    private

    def set_preference
      @preference = Preference.find_by(code: code)
      raise Common::Exceptions::RecordNotFound, code if @preference.blank?
    end

    def preference_params
      params.permit(:code)
    end

    def code
      preference_params['code']
    end
  end
end
