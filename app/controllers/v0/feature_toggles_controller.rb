# frozen_string_literal: true

module V0
  class FeatureTogglesController < ApplicationController
    service_tag 'feature-flag'
    # the feature toggle does not require authentication, but if a user is logged we might use @current_user
    skip_before_action :authenticate

    def index
      load_user_if_session_exists

      if params[:features].present?
        features_params = params[:features].split(',')
        features = feature_toggles_service.get_features(features_params)
      else
        features = feature_toggles_service.get_all_features
      end

      render json: { data: { type: 'feature_toggles', features: } }
    end

    private

    def load_user_if_session_exists
      if Flipper.enabled?(:load_user_if_authenticated)
        load_user_safely
      else
        load_user
      end
    end

    def load_user_safely
      if session[:token].present?
        set_session_object
        set_current_user(false)
      else
        @current_user = nil
        @session_object = nil
      end
    rescue => e
      Rails.logger.debug { "FeatureToggles: Error loading user - #{e.message}" }
      @current_user = nil
      @session_object = nil
    end

    def feature_toggles_service
      @feature_toggles_service ||= FeatureTogglesService.new(
        current_user: @current_user,
        cookie_id: params[:cookie_id]
      )
    end
  end
end
