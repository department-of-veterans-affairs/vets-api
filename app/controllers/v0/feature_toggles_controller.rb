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
      sql = <<-SQL.squish
        SELECT flipper_features.key AS feature_name,
              MAX(CASE
                    WHEN flipper_gates.key = 'boolean' AND flipper_gates.value = 'true' THEN 1
                    WHEN flipper_gates.key = 'actors' AND flipper_gates.value = ? THEN 1
                    ELSE 0
                  END) = 1 AS enabled
        FROM flipper_features
        LEFT JOIN flipper_gates
          ON flipper_features.key = flipper_gates.feature_key
        GROUP BY flipper_features.key;
      SQL

      results = ActiveRecord::Base.connection.select_all(ActiveRecord::Base.sanitize_sql_array([sql, flipper_id]))

      results.each_with_object([]) do |row, array|
        if row['enabled']
          feature_name = row['feature_name']
          array << { name: feature_name.camelize(:lower), value: row['enabled'] }
          array << { name: feature_name, value: row['enabled'] }
        end
      end
    end

    def flipper_id
      params[:cookie_id] || @current_user&.flipper_id
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
