# frozen_string_literal: true

# lib/flipper_utils.rb
module FlipperUtils
  # catch that annoying set of errors that happens during startup on a couple of configurations
  # What's happening is that Flipper is not fully initialized and enabled and calls like
  # Flipper.enabled?(feature_name) throw an exception which produces an error in the log on startup.
  # These errors also appear anytime you run a migration or a couple of other tasks.
  def self.safe_enabled?(feature_name)
    return false unless defined?(Flipper) && Flipper.respond_to?(:enabled)

    Flipper.enabled?(feature_name)
  end

  # Manage Flipper feature setup: adding missing features, enabling defaults, removing orphans
  class FeatureManager
    attr_reader :added_features, :enabled_features, :removed_features

    def initialize
      @added_features = []
      @enabled_features = []
      @removed_features = []
    end

    def setup
      # Add missing features
      features_config['features'].each do |feature, feature_config|
        add_if_missing(feature, feature_config)
      end

      # Remove features that are no longer in config/features.yml
      Flipper.features.each { remove_if_orphaned(_1) }

      # Log results
      log_results
    rescue Psych::SyntaxError => e
      Rails.logger.error "Error parsing config/features.yml while processing Flipper features: #{e.message}"
      raise e # Re-raise so rake task fails visibly
    rescue ActiveRecord::ConnectionNotEstablished => e
      Rails.logger.error "Database connection error while processing Flipper features: #{e.message}"
      raise e # Re-raise so rake task fails visibly
    rescue e
      Rails.logger.error "Unexpected error processing Flipper features: #{e.message}"
      raise e # Re-raise so rake task fails visibly
    end

    private

    def features_config = YAML.safe_load(Rails.root.join('config', 'features.yml').read)
    def config_feature_names = features_config['features'].keys

    def add_if_missing(feature, feature_config)
      unless Flipper.exist?(feature)
        Flipper.add(feature)
        added_features << feature

        # Default features to enabled for test and those explicitly set for development
        should_enable =
          Rails.env.test? ||
          (Rails.env.development? && feature_config['enable_in_development']) ||
          (Settings.vsp_environment.to_s == 'development' && feature_config['enable_in_development'])

        if should_enable
          Flipper.enable(feature)
          enabled_features << feature
        end
      end
    end

    def remove_if_orphaned(feature)
      unless config_feature_names.include?(feature.name)
        feature.remove
        removed_features << feature.name
      end
    end

    def log_results
      if added_features.any?
        Rails.logger.info("features:setup added #{added_features.count} features: #{added_features.join(', ')}")
      else
        Rails.logger.info('features:setup - no new features to add')
      end

      if enabled_features.any?
        Rails.logger.info("features:setup enabled #{enabled_features.count} features: #{enabled_features.join(', ')}")
      end

      if removed_features.any?
        message = "features:setup removed #{removed_features.count} orphaned features: #{removed_features.join(', ')}"
        Rails.logger.info(message)
      end
    end
  end

  def self.setup_features
    manager = FeatureManager.new
    manager.setup
    { added: manager.added_features,
      enabled: manager.enabled_features,
      removed: manager.removed_features }
  end
end
