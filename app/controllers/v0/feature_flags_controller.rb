# frozen_string_literal: true

module V0
  class FeatureFlagsController < ApplicationController
    # the feature flag does not require authentication, but if a user is logged we might use @current_user
    skip_before_action :authenticate
    before_action :validate_session

    def index
      features_params = params[:features].split(',')
      features_hash = {}
      features_params.each do |feature_name|
        features_hash[feature_name] = Flipper.enabled?(feature_name, @current_user)
      end

      render json: features_hash
    end
  end
end
