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

        { name: feature_name, value: Flipper.enabled?(underscored_feature_name, resolve_actor(actor_type)) }
      end
    end

    def get_all_features
      return old_get_all_features unless Flipper.enabled?(:use_new_get_all_features)

      features = fetch_features_with_gate_keys
      add_feature_gate_values(features)
      format_features(features)
    end

    def fetch_features_with_gate_keys
      FLIPPER_FEATURE_CONFIG['features']
        .map { |name, config| { name:, enabled: false, actor_type: config['actor_type'] } }
        .tap do |features|
          # Update enabled to true if globally enabled
          feature_gates.each do |row|
            feature = features.find { |f| f[:name] == row['feature_name'] }
            next unless feature # Ignore features not in config/features.yml

            feature[:gate_key] = row['gate_key'] # Add gate_key for use in add_feature_gate_values
            feature[:enabled] = true if row['gate_key'] == 'boolean' && row['value'] == 'true'
          end
        end
    end

    def add_feature_gate_values(features)
      features.each do |feature|
        # If globally enabled, don't disable for percentage or actors
        next if feature[:enabled] || %w[actors percentage_of_actors percentage_of_time].exclude?(feature[:gate_key])

        # There's only a handful of these so individually querying them doesn't take long
        feature[:enabled] = Flipper.enabled?(feature[:name], resolve_actor(feature[:actor_type]))
      end
    end

    def format_features(features)
      features.flat_map do |feature|
        [
          { name: feature[:name].camelize(:lower), value: feature[:enabled] },
          { name: feature[:name], value: feature[:enabled] }
        ]
      end
    end

    def resolve_actor(actor_type)
      if actor_type == FLIPPER_ACTOR_STRING
        Flipper::Actor.new(params[:cookie_id])
      else
        @current_user
      end
    end

    def feature_gates
      Rails.cache.fetch('global_feature_gates', expires_in: 1.minute) do
        ActiveRecord::Base.connection.select_all(<<-SQL.squish)
          SELECT flipper_features.key AS feature_name, flipper_gates.key AS gate_key, flipper_gates.value
          FROM flipper_features
          LEFT JOIN flipper_gates ON flipper_features.key = flipper_gates.feature_key
        SQL
      end
    end

    def flipper_id
      params[:cookie_id] || @current_user&.flipper_id
    end

    def old_get_all_features
      features = []

      FLIPPER_FEATURE_CONFIG['features'].collect do |feature_name, values|
        flipper_enabled = if Settings.flipper.mute_logs
                            ActiveRecord::Base.logger.silence do
                              Flipper.enabled?(feature_name, resolve_actor(values['actor_type']))
                            end
                          else
                            Flipper.enabled?(feature_name, resolve_actor(values['actor_type']))
                          end
        # returning both camel and snakecase for uniformity on FE
        features << { name: feature_name.camelize(:lower), value: flipper_enabled }
        features << { name: feature_name, value: flipper_enabled }
      end

      features
    end
  end
end
