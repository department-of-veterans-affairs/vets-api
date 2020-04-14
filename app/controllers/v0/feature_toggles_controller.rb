# frozen_string_literal: true

module V0
  class FeatureTogglesController < ApplicationController
    # the feature toggle does not require authentication, but if a user is logged we might use @current_user
    skip_before_action :authenticate
    before_action :load_user

    def index
      if params[:features].present?
        features_params = params[:features].split(',')

        features = features_params.collect do |feature_name|
          underscored_feature_name = feature_name.underscore
          { name: feature_name, value: Flipper.enabled?(underscored_feature_name, actor(underscored_feature_name)) }
        end
      else
        features = []
      end
      render json: { data: { type: 'feature_toggles', features: features } }
    end

    def actor(feature_name)
      if FLIPPER_FEATURE_CONFIG['features'].dig(feature_name, 'actor_type') == FLIPPER_ACTOR_STRING
        Flipper::Actor.new(params[:cookie_id])
      else
        @current_user
      end
    end
  end
end
