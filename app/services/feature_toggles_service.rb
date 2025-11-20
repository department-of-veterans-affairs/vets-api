# frozen_string_literal: true

class FeatureTogglesService
  attr_reader :current_user, :cookie_id

  # Initialize the service with the current user and cookie ID
  #
  # @param [User] current_user - The current authenticated user (optional)
  # @param [String] cookie_id - The cookie ID for anonymous users (optional)
  def initialize(current_user: nil, cookie_id: nil)
    @current_user = current_user
    @cookie_id = cookie_id
  end

  # Get specific features based on provided feature names
  #
  # @param [Array<String>] features_params - List of feature names to check
  # @return [Array<Hash>] - Array of feature name/value pairs
  def get_features(features_params)
    features_params.collect do |feature_name|
      underscored_feature_name = feature_name.underscore
      actor_type = FLIPPER_FEATURE_CONFIG['features'].dig(feature_name, 'actor_type')

      { name: feature_name, value: Flipper.enabled?(underscored_feature_name, resolve_actor(actor_type)) }
    end
  end

  # Get all features and their values
  #
  # @return [Array<Hash>] - Array of all feature name/value pairs
  def get_all_features
    features = fetch_features_with_gate_keys
    add_feature_gate_values(features)
    format_features(features)
  end

  private

  # Fetch features with their gate keys
  #
  # @return [Array<Hash>] - Array of features with gate keys
  def fetch_features_with_gate_keys
    Rails.cache.fetch('features_with_gate_keys', expires_in: 1.minute) do
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
  end

  # Add feature gate values to features
  #
  # @param [Array<Hash>] features - Features to add gate values to
  def add_feature_gate_values(features)
    features.each do |feature|
      # If globally enabled, don't disable for percentage or actors
      next if feature[:enabled] || %w[actors percentage_of_actors percentage_of_time].exclude?(feature[:gate_key])

      # There's only a handful of these so individually querying them doesn't take long
      feature[:enabled] =
        if Settings.flipper.mute_logs
          ActiveRecord::Base.logger.silence do
            Flipper.enabled?(feature[:name], resolve_actor(feature[:actor_type]))
          end
        else
          Flipper.enabled?(feature[:name], resolve_actor(feature[:actor_type]))
        end
    end
  end

  # Format features for response
  #
  # @param [Array<Hash>] features - Features to format
  # @return [Array<Hash>] - Formatted features
  def format_features(features)
    features.flat_map do |feature|
      [
        { name: feature[:name].camelize(:lower), value: feature[:enabled] },
        { name: feature[:name], value: feature[:enabled] }
      ]
    end
  end

  # Resolve the actor for Flipper based on actor type
  #
  # @param [String] actor_type - The type of actor
  # @return [User, Flipper::Actor] - The resolved actor
  def resolve_actor(actor_type)
    if actor_type == FLIPPER_ACTOR_STRING
      Flipper::Actor.new(cookie_id)
    else
      current_user
    end
  end

  # Get feature gates from the database
  #
  # @return [Array<Hash>] - Database results with feature gates
  def feature_gates
    ActiveRecord::Base.connection.select_all(<<-SQL.squish)
      SELECT flipper_features.key AS feature_name, flipper_gates.key AS gate_key, flipper_gates.value
      FROM flipper_features
      LEFT JOIN flipper_gates ON flipper_features.key = flipper_gates.feature_key
    SQL
  end
end
