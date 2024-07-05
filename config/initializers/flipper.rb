# frozen_string_literal: true

require 'flipper'
require 'flipper/adapters/active_record'
require 'active_support/cache'
require 'flipper/adapters/active_support_cache_store'
require 'flipper/action_patch'
require 'flipper/configuration_patch'
require 'flipper/instrumentation/event_subscriber'

FLIPPER_FEATURE_CONFIG = YAML.safe_load(File.read(Rails.root.join('config', 'features.yml')))

Rails.application.configure do
  config.flipper.test_help = false
end

Rails.application.reloader.to_prepare do
  Flipper.configure do |config|
    config.default do
      activerecord_adapter = Flipper::Adapters::ActiveRecord.new
      cache = Rails.cache
      expires_in = 1.minute

      # Flipper settings will be stored in postgres and cached in memory for 1 minute in production/staging
      cached_adapter = Flipper::Adapters::ActiveSupportCacheStore.new(activerecord_adapter, cache, expires_in)
      instrumented = Flipper::Adapters::Instrumented.new(cached_adapter, instrumenter: ActiveSupport::Notifications)

      Flipper.new(instrumented, instrumenter: ActiveSupport::Notifications)
    end
  end

  # Modify Flipper::UI::Configuration to accept a custom view path.
  Flipper::UI::Configuration.prepend(FlipperExtensions::ConfigurationPatch)

  Flipper::UI.configure do |config|
    config.custom_views_path = Rails.root.join('lib', 'flipper', 'views')
  end

  FLIPPER_ACTOR_USER = 'user'
  FLIPPER_ACTOR_STRING = 'cookie_id'

  Flipper::UI.configuration.feature_creation_enabled = false
  # Make sure that each feature we reference in code is present in the UI, as long as we have a Database already
  begin
    FLIPPER_FEATURE_CONFIG['features'].each do |feature, feature_config|
      unless Flipper.exist?(feature)
        Flipper.add(feature)

        # Default features to enabled for test and those explicitly set for development
        if Rails.env.test? || (Rails.env.development? && feature_config['enable_in_development'])
          Flipper.enable(feature)
        end
      end

      # Enable features on dev-api.va.gov if they are set to enable_in_development
      Flipper.enable(feature) if Settings.vsp_environment == 'development' && feature_config['enable_in_development']
    end

    removed_features = Flipper.features.collect(&:name) - FLIPPER_FEATURE_CONFIG['features'].keys
    Rails.logger.warn "Consider removing features no longer in config/features.yml: #{removed_features.join(', ')}"
  rescue
    # make sure we can still run rake tasks before table has been created
    nil
  end

  # Modify Flipper::UI::Action to use custom views if they exist
  # and to add descriptions and types for features.
  Flipper::UI::Action.prepend(FlipperExtensions::ActionPatch)
end
