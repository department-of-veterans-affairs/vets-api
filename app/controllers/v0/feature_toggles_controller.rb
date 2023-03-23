# frozen_string_literal: true

module V0
  class FeatureTogglesController < ApplicationController
    # the feature toggle does not require authentication, but if a user is logged we might use @current_user
    skip_before_action :authenticate
    before_action :load_user

    def index
      if params[:features].present?
        features_params = params[:features].split(',')
        features = get_features(features_params)
      else
        features = get_all_features
      end

      render json: { data: { type: 'feature_toggles', features: } }
    end

    private

    def get_features(features_params)
      features_params.collect do |feature_name|
        underscored_feature_name = feature_name.underscore
        actor_type = FLIPPER_FEATURE_CONFIG['features'].dig(feature_name, 'actor_type')

        { name: feature_name, value: Flipper.enabled?(underscored_feature_name, actor(actor_type)) }
      end
    end

    def get_all_features
      features = []

      FLIPPER_FEATURE_CONFIG['features'].collect do |feature_name, values|
        flipper_enabled = if Settings.flipper.mute_logs
                            ActiveRecord::Base.logger.silence do
                              Flipper.enabled?(feature_name, actor(values['actor_type']))
                            end
                          else
                            Flipper.enabled?(feature_name, actor(values['actor_type']))
                          end
        # returning both camel and snakecase for uniformity on FE
        features << { name: feature_name.camelize(:lower), value: flipper_enabled }
        features << { name: feature_name, value: flipper_enabled }
      end

      features
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
