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
          { name: feature_name, value: Flipper.enabled?(feature_name.underscore, actor(feature_name.underscore)) }
        end
      else
        features = []
      end
      render json: { data: { type: 'feature_toggles', features: features } }
    end
  end

  FlipperActor = Struct.new(:id_str) do
    def flipper_id
      id_str
    end
  end

  def actor(feature_name)
    if FLIPPER_FEATURE_CONFIG['features'].dig(feature_name, 'actor') == 'cookie_id'
      FlipperActor.new(params[:cookie_id])
    else
      @current_user
    end
  end
end
