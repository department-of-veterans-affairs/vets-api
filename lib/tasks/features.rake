# frozen_string_literal: true

require 'flipper'

namespace :features do
  desc 'Setup Flipper features from config/features.yml'
  task setup: :environment do
    features_config = YAML.safe_load(Rails.root.join('config', 'features.yml').read)
    added_features = []
    enabled_features = []

    features_config['features'].each do |feature, feature_config|
      unless Flipper.exist?(feature)
        Flipper.add(feature)
        added_features << feature

        # Default features to enabled for test and those explicitly set for development
        if Rails.env.test? || (Rails.env.development? && feature_config['enable_in_development'])
          Flipper.enable(feature)
          enabled_features << feature
        end
      end

      # Enable features on dev-api.va.gov if they are set to enable_in_development
      if Settings.vsp_environment == 'development' && feature_config['enable_in_development']
        Flipper.enable(feature)
        enabled_features << feature unless enabled_features.include?(feature)
      end
    end

    if added_features.any?
      Rails.logger.info("features:setup added #{added_features.count} features: #{added_features.join(', ')}")
    else
      Rails.logger.info('features:setup - no new features to add')
    end

    if enabled_features.any?
      Rails.logger.info("features:setup enabled #{enabled_features.count} features: #{enabled_features.join(', ')}")
    end

    # Warn about features in database that are not in config
    removed_features = Flipper.features.collect(&:name) - features_config['features'].keys
    if removed_features.any?
      Rails.logger.warn(
        "features:setup - consider removing features no longer in config/features.yml: #{removed_features.join(', ')}"
      )
    end
  end
end
