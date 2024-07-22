# frozen_string_literal: true

module V0
  class FeatureTogglesController < ApplicationController
    service_tag 'feature-flag'
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
        flipper_enabled = flipper_enabled? get_feature_flags_for_actor, feature_name, actor(values['actor_type'])

        # returning both camel and snakecase for uniformity on FE
        features << { name: feature_name.camelize(:lower), value: flipper_enabled }
        features << { name: feature_name, value: flipper_enabled }
      end

      features
    end

    def get_feature_flags_for_actor
      if actor_has_custom_features?
        flipper_get_all
      else
        cache_global_features
      end
    end

    def actor_has_custom_features?
      @actor_has_custom_features ||= begin
        actor = params[:cookie_ids] || @current_user
        if actor.present?
          result = ActiveRecord::Base.connection.select_value(
            "SELECT 1 FROM flipper_gates WHERE flipper_gates.key = 'actors' AND flipper_gates.value = ? LIMIT 1",
            [actor]
          )

          !result.nil?
        else
          false
        end
      end
    end

    def flipper_get_all
      if Settings.flipper.mute_logs
        ActiveRecord::Base.logger.silence do
          Flipper.adapter.get_all
        end
      else
        Flipper.adapter.get_all
      end
    end

    def cache_global_features
      Rails.cache.fetch('global_feature_flags', expires_in: 1.minute) do
        flipper_get_all
      end
    end

    def flipper_enabled?(all_features, feature, actor)
      gates = all_features.select { |feature_name| feature_name == feature }.values.first
      gates[:actors].include?(actor&.flipper_id) || gates[:groups].include?('all') || gates[:boolean] == 'true'
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
