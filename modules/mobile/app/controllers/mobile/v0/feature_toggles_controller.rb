# frozen_string_literal: true

module Mobile
  module V0
    class FeatureTogglesController < ApplicationController
      # the feature toggle does not require authentication, but if a user is logged we might use @current_user
      skip_before_action :authenticate
      before_action :set_current_user

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

      def set_current_user
        # Try to load user if possible, but don't throw errors if not authenticated
        load_user(skip_expiration_check: true)
      rescue => e
        Rails.logger.info("Error loading user in feature toggles: #{e.message}")
        @current_user = nil
      end
    end
  end
end
