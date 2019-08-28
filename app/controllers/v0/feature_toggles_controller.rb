# frozen_string_literal: true

module V0
  class FeatureTogglesController < ApplicationController
    # the feature toggle does not require authentication, but if a user is logged we might use @current_user
    skip_before_action :authenticate
    before_action :validate_session

    def index
      if params[:features].present?
        features_params = params[:features].split(',')

        features = features_params.collect do |feature_name|
          { name: feature_name, value: Flipper.enabled?(feature_name.underscore, @current_user) }
        end
      else
        features = []
      end
      render json: { data: { type: 'feature_toggles', features: features } }
    end
  end
end
