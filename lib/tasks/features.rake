# frozen_string_literal: true

require 'flipper'

namespace :features do
  desc 'Setup Flipper features from config/features.yml (adds missing features, removes orphaned features)'
  task setup: :environment do
    added_features = []
    enabled_features = []
    removed_features = []

    begin
      features_config = YAML.safe_load(Rails.root.join('config', 'features.yml').read)
      config_feature_names = features_config['features'].keys

      # Add missing features
      features_config['features'].each do |feature, feature_config|
        unless Flipper.exist?(feature)
          Flipper.add(feature)
          added_features << feature

          # Default features to enabled for test and those explicitly set for development
          if Rails.env.test? || (Rails.env.development? && feature_config['enable_in_development'])
            Flipper.enable(feature)
            enabled_features << feature
          end

          # Enable features on dev-api.va.gov if they are set to enable_in_development
          if Settings.vsp_environment.to_s == 'development' && feature_config['enable_in_development']
            Flipper.enable(feature)
            enabled_features << feature unless enabled_features.include?(feature)
          end
        end
      end

      # Remove features that are no longer in config/features.yml
      Flipper.features.each do |feature|
        unless config_feature_names.include?(feature.name)
          feature.remove
          removed_features << feature.name
        end
      end

      # Log results
      if added_features.any?
        Rails.logger.info("features:setup added #{added_features.count} features: #{added_features.join(', ')}")
      else
        Rails.logger.info('features:setup - no new features to add')
      end

      if enabled_features.any?
        Rails.logger.info("features:setup enabled #{enabled_features.count} features: #{enabled_features.join(', ')}")
      end

      if removed_features.any?
        Rails.logger.info("features:setup removed #{removed_features.count} \
          orphaned features: #{removed_features.join(', ')}")
      end
    rescue => e
      Rails.logger.error "Error processing Flipper features: #{e.message}"
      raise e # Re-raise so rake task fails visibly
    end
  end
end
