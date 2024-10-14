# frozen_string_literal: true

require 'flipper'
require 'flipper/adapters/active_record'
require 'active_support/cache'
require 'flipper/adapters/active_support_cache_store'
require 'flipper/ui/action_patch'
require 'flipper/instrumentation/event_subscriber'

FLIPPER_FEATURE_CONFIG = YAML.safe_load(File.read(Rails.root.join('config', 'features.yml')))

Rails.application.configure do
  config.flipper.test_help = false
  config.flipper.log = false
end

Rails.application.reloader.to_prepare do
  FLIPPER_ACTOR_USER = 'user'
  FLIPPER_ACTOR_STRING = 'cookie_id'

  # Modify Flipper::UI::Action to use our custom views
  Flipper::UI::Action.prepend(Flipper::UI::ActionPatch)

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

  Flipper::UI.configure do |config|
    config.feature_creation_enabled = false
    config.feature_removal_enabled = false
    config.show_feature_description_in_list = true
    config.confirm_disable = true
    config.confirm_fully_enable = true
    config.descriptions_source = lambda do |_keys|
      FLIPPER_FEATURE_CONFIG['features'].transform_values { |value| value['description'] }
    end
  end

  # Make sure that each feature we reference in code is present in the UI, as long as we have a Database already
  added_flippers = []
  begin
    FLIPPER_FEATURE_CONFIG['features'].each do |feature, feature_config|
      unless Flipper.exist?(feature)
        Flipper.add(feature)
        added_flippers.push(feature)

        # Default features to enabled for test and those explicitly set for development
        if Rails.env.test? || (Rails.env.development? && feature_config['enable_in_development'])
          Flipper.enable(feature)
        end
      end

      # Enable features on dev-api.va.gov if they are set to enable_in_development
      Flipper.enable(feature) if Settings.vsp_environment == 'development' && feature_config['enable_in_development']
    end

    Rails.logger.info "The following feature flippers were added: #{added_flippers}" unless added_flippers.empty?
    removed_features = Flipper.features.collect(&:name) - FLIPPER_FEATURE_CONFIG['features'].keys
    unless removed_features.empty?
      Rails.logger.warn "Consider removing features no longer in config/features.yml: #{removed_features.join(', ')}"
    end
  rescue => e
    Rails.logger.error "Error processing Flipper features: #{e.message}"
    # make sure we can still run rake tasks before table has been created
    nil
  end
end
