# frozen_string_literal: true

module V0
  class FeatureTogglesController < ApplicationController
    # the feature toggle does not require authentication, but if a user is logged we might use @current_user
    skip_before_action :authenticate
    before_action :load_user

    def index
      features_array = []

      if params[:features].present?
        features_params = params[:features].split(',')

        features_params.each do |feature_name|
          underscored_feature_name = feature_name.underscore
          actor_type = FLIPPER_FEATURE_CONFIG['features'].dig(feature_name, 'actor_type')
          feature_enabled = Flipper.enabled?(underscored_feature_name, actor(actor_type))
          add_feature_to_features_array(features_array, feature_name, feature_enabled)
        end
      else
        FLIPPER_FEATURE_CONFIG['features'].collect do |feature_name, values|
          feature_enabled = Flipper.enabled?(feature_name, actor(values['actor_type']))
          add_feature_to_features_array(features_array, feature_name, feature_enabled)
        end
      end

      render json: { data: { type: 'feature_toggles', features: features_array } }
    end

    private

    def actor(actor_type)
      if actor_type == FLIPPER_ACTOR_STRING
        Flipper::Actor.new(params[:cookie_id])
      else
        @current_user
      end
    end

    # returning both camel and snakecase for uniformity on FE
    def add_feature_to_features_array(features_array, feature, value)
      features_array << { name: feature.camelize(:lower), value: value }
      features_array << { name: feature.snakecase, value: value }
    end
  end
end
