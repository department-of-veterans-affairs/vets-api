# frozen_string_literal: true

module V0
  class FeatureTogglesController < ApplicationController
    # the feature toggle does not require authentication, but if a user is logged we might use @current_user
    skip_before_action :authenticate
    before_action :load_user

    def index
      features = []
      FLIPPER_FEATURE_CONFIG['features'].collect do |feature_name, values|
        features << { name: feature_name.camelize(:lower),
                      value: Flipper.enabled?(feature_name, actor(values['actor_type'])) }
        features << { name: feature_name, value: Flipper.enabled?(feature_name, actor(values['actor_type'])) }
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
