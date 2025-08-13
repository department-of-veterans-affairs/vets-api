# frozen_string_literal: true

module V0
  class FeatureTogglesController < ApplicationController
    service_tag 'feature-flag'
    # the feature toggle does not require authentication, but if a user is logged we might use @current_user
    skip_before_action :authenticate
    before_action :load_user

    def index
      if params[:features].present?
        features_params = params[:features].split(',')
        features = feature_toggles_service.get_features(features_params)
      else
        features = feature_toggles_service.get_all_features
      end

      render json: { data: { type: 'feature_toggles', features: } }
    end

    private

    def feature_toggles_service
      @feature_toggles_service ||= FeatureTogglesService.new(
        current_user: @current_user,
        cookie_id: params[:cookie_id]
      )
    end
  end
end
