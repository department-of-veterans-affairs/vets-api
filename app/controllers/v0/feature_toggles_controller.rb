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
          actor_type = FLIPPER_FEATURE_CONFIG['features'].dig(feature_name, 'actor_type')

          { name: feature_name, value: Flipper.enabled?(underscored_feature_name, actor(actor_type)) }
        end
      else
        features = []

        # returning both camel and snakecase for uniformity on FE
        FLIPPER_FEATURE_CONFIG['features'].collect do |feature_name, values|
          flipper_enabled = Flipper.enabled?(feature_name, actor(values['actor_type']))
          features << { name: feature_name.camelize(:lower),
                        value: flipper_enabled }
          features << { name: feature_name, value: flipper_enabled }
        end
      end

      render json: { data: { type: 'feature_toggles', features: features } }
    end

    def actor(actor_type)
      if actor_type == FLIPPER_ACTOR_STRING
        Flipper::Actor.new(params[:cookie_id])
      else
        @current_user
      end
    end
  end
end
