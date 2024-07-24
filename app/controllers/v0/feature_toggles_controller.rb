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
        features = get_all_features.map { |feature| feature.except(:gate_key) }
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

      results = enabled_features
      results.each do |feature|
        next if feature[:value]

        feature_name = feature[:name]
        gate = feature_gates.find {|feature| feature[:feature_name] == feature_name }
        gate_key = gate && gate[:gate_key]

        feature_config = FLIPPER_FEATURE_CONFIG['features'][feature_name]
        actor_type = feature_config ? feature_config['actor_type'] : FLIPPER_ACTOR_STRING
        actor = resolve_actor(actor_type)

        if %w[actors percentage_of_actors percentage_of_time].include?(gate_key)
          enabled = Flipper.enabled?(feature_name, actor)
          feature[:value] = enabled
        end
      end

      new_results = [ ]
      results.each do |result|
        new_results << { name: result[:name].camelize(:lower), value: result[:value] }
        new_results << { name: result[:name], value: result[:value] }
      end

      new_results
    end

    def resolve_actor(actor_type)
      if actor_type == FLIPPER_ACTOR_STRING
        Flipper::Actor.new(params[:cookie_id])
      else
        @current_user
      end
    end

    def feature_gates
      ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql_array([feature_gates_sql])
      ).each_with_object([]) do |row, array|
        array << { feature_name: row['feature_name'], gate_key: row['gate_key'] }
      end
    end

    def feature_gates_sql
      <<-SQL.squish
        SELECT 
            flipper_features.key AS feature_name, 
            flipper_gates.key AS gate_key
        FROM 
            flipper_features
        LEFT JOIN 
            flipper_gates
        ON 
            flipper_features.key = flipper_gates.feature_key
        WHERE 
            flipper_gates.key != 'boolean'
      SQL
    end

    def enabled_features
      results = ActiveRecord::Base.connection.select_all(
        ActiveRecord::Base.sanitize_sql_array([enabled_features_sql])
      ).each_with_object([]) do |row, array|
        feature_name = row['feature_name']
        enabled = row['value'] == "true"

        array << { name: feature_name, value: enabled }
      end

      existing_feature_names = results.map { |result| result[:name] }
      missing_features = FLIPPER_FEATURE_CONFIG['features'].keys - existing_feature_names

      missing_features.each do |feature|
        results << { name: feature, value: false }
      end

      results
    end

    def enabled_features_sql
      <<-SQL.squish
        SELECT 
            flipper_features.key AS feature_name, 
            flipper_gates.key AS gate_key, 
            flipper_gates.value
        FROM 
            flipper_features
        LEFT JOIN 
            flipper_gates
        ON 
            flipper_features.key = flipper_gates.feature_key
        WHERE 
            flipper_gates.key = 'boolean';
      SQL
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

    def flipper_id
      params[:cookie_id] || @current_user&.flipper_id
    end
  end
end
