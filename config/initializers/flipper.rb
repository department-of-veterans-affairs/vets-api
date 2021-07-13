# frozen_string_literal: true

require 'flipper'
require 'flipper/adapters/active_record'
require 'active_support/cache'
require 'flipper/adapters/active_support_cache_store'
require 'flipper/action_patch'
require 'flipper/configuration_patch'
require 'flipper/instrumentation/event_subscriber'

FLIPPER_FEATURE_CONFIG = YAML.safe_load(File.read(Rails.root.join('config', 'features.yml')))

Rails.application.reloader.to_prepare do
  Flipper.configure do |config|
    config.default do
      activerecord_adapter = Flipper::Adapters::ActiveRecord.new
      cache = ActiveSupport::Cache::MemoryStore.new
      # Flipper settings will be stored in postgres and cached in memory for 1 minute in production/staging
      cached_adapter = Flipper::Adapters::ActiveSupportCacheStore.new(activerecord_adapter, cache, expires_in: 1.minute)
      adapter = Rails.env.development? || Rails.env.test? ? activerecord_adapter : cached_adapter
      instrumented = Flipper::Adapters::Instrumented.new(adapter, instrumenter: ActiveSupport::Notifications)
      # pass adapter to handy DSL instance
      Flipper.new(instrumented, instrumenter: ActiveSupport::Notifications)
    end
  end

  # Modify Flipper::UI::Configuration to accept a custom view path.
  Flipper::UI::Configuration.prepend(FlipperExtensions::ConfigurationPatch)

  Flipper::UI.configure do |config|
    config.custom_views_path = Rails.root.join('lib', 'flipper', 'views')
  end

  # A contrived example of how we might use a "group"
  # (a method that can be evaluated at runtime to determine feature status)
  #
  # Flipper.register(:first_name_is_hector) do |user|
  #   user.respond_to?(:first_name) && user.first_name == 'HECTOR'
  # end
  FLIPPER_ACTOR_USER = 'user'
  FLIPPER_ACTOR_STRING = 'cookie_id'

  Flipper::UI.configuration.feature_creation_enabled = false
  # Make sure that each feature we reference in code is present in the UI, as long as we have a Database already
  begin
    FLIPPER_FEATURE_CONFIG['features'].each do |feature, feature_config|
      unless Flipper.exist?(feature)
        Flipper.add(feature)

        # default features to enabled for test and those explicitly set for development
        if Rails.env.test? ||
           (Rails.env.development? && feature_config['enable_in_development']) ||
           (Settings.vsp_environment == 'development' && feature_config['enable_in_development'])
          Flipper.enable(feature)
        end
      end
    end
    # remove features from UI that have been removed from code
    removed_features = (Flipper.features.collect(&:name) - FLIPPER_FEATURE_CONFIG['features'].keys)
    removed_features.each { |feature_name| Flipper.remove(feature_name) }
  rescue
    # make sure we can still run rake tasks before table has been created
    nil
  end

  # Modify Flipper::UI::Action to use custom views if they exist
  # and to add descriptions and types for features.
  Flipper::UI::Action.prepend(FlipperExtensions::ActionPatch)
end
