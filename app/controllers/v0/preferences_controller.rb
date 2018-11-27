# frozen_string_literal: true

module V0
  class PreferencesController < ApplicationController
    before_action :set_preference, only: :show

    def index
      results = Preference.all
      render json: results,
             each_serializer: PreferenceSerializer
    end

    def show
      render json: @preference
    end

    private

    def set_preference
      @preference = Preference.find_by(code: preference_params['code'])
      raise Common::Exceptions::RecordNotFound, preference_params['code'] if @preference.blank?
    end

    def preference_params
      params.permit(:code)
    end
  end
end
