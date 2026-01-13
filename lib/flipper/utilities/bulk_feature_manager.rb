# frozen_string_literal: true

module Flipper
  module Utilities
    # Manage Flipper feature setup: adding missing features, enabling defaults, removing orphans
    class BulkFeatureManager
      attr_reader :added_features, :enabled_features, :removed_features

      def initialize(flipper = Flipper, dry_run: false)
        @flipper = flipper
        @dry_run = dry_run
        @added_features = []
        @enabled_features = []
        @removed_features = []
      end

      # Add/enable/remove features based on config/features.yml
      def setup
        # Add missing features
        features_config['features'].each do |feature, feature_config|
          add_if_missing(feature, feature_config)
        end

        # Remove features that are no longer in config/features.yml
        orphaned = @flipper.features.select(&method(:orphaned?))
        orphaned.each { |f| remove_if_orphaned(f) }

        # Log results
        log_results
      rescue Psych::SyntaxError => e
        Rails.logger.error "Error parsing config/features.yml while processing Flipper features: #{e.message}"
        raise e # Re-raise so rake task fails visibly
      rescue ActiveRecord::ConnectionNotEstablished => e
        Rails.logger.error "Database connection error while processing Flipper features: #{e.message}"
        raise e # Re-raise so rake task fails visibly
      end

      private

      attr_reader :dry_run

      def features_config
        @features_config ||= YAML.safe_load(Rails.root.join('config', 'features.yml').read)
        unless @features_config.is_a?(Hash) && @features_config.key?('features') && @features_config['features'].is_a?(Hash)
          raise ArgumentError, "Invalid config/features.yml format: expected top-level 'features' map (#{Rails.env})"
        end

        @features_config
      end

      def config_feature_names = @config_feature_names ||= features_config['features'].keys

      def add_if_missing(feature, feature_config)
        unless @flipper.exist?(feature)
          added_features << feature
          @flipper.add(feature) unless @dry_run

          # Default features to enabled for test and those explicitly set for development
          should_enable =
            Rails.env.test? ||
            (Rails.env.development? && feature_config['enable_in_development']) ||
            (Settings.vsp_environment == 'development' && feature_config['enable_in_development'])

          if should_enable
            enabled_features << feature
            @flipper.enable(feature) unless @dry_run
          end
        end
      end

      def orphaned?(feature) = config_feature_names.exclude?(feature.name)

      def remove_if_orphaned(feature)
        unless config_feature_names.include?(feature.name)
          removed_features << feature.name
          feature.remove unless @dry_run
        end
      end

      def log_results
        if added_features.any?
          message = "features:setup #{dry_run ? 'would add' : 'added'} #{added_features.count} features: "
          message += added_features.join(', ')
          Rails.logger.info(message)
        else
          Rails.logger.info('features:setup - no new features to add')
        end

        if enabled_features.any?
          message = "features:setup #{dry_run ? 'would enable' : 'enabled'} #{enabled_features.count} features: "
          message += enabled_features.join(', ')
          Rails.logger.info(message)
        end

        if removed_features.any?
          message = "features:setup #{dry_run ? 'would remove' : 'removed'} #{removed_features.count} features: "
          message += removed_features.join(', ')
          Rails.logger.warn(message)
        end
      end
    end

    def self.setup_features(flipper = Flipper, dry_run: false)
      manager = BulkFeatureManager.new(flipper, dry_run:)
      manager.setup
      { added: manager.added_features,
        enabled: manager.enabled_features,
        removed: manager.removed_features }
    end
  end
end
