# frozen_string_literal: true

require 'flipper'
require 'flipper/adapters/active_record'
require 'active_support/cache'
require 'flipper/adapters/active_support_cache_store'
require 'flipper/action_patch'
require 'flipper/configuration_patch'

require 'flipper/instrumentation/event_subscriber'

FLIPPER_FEATURE_CONFIG = YAML.safe_load(File.read(Rails.root.join('config', 'features.yml')))

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

  # Labeling what Flipper calls "actors" as "users" in the UI
  config.actors.title = 'Users'
  config.percentage_of_actors.title = 'Percentage of Actors'
  config.percentage_of_actors.description = %(By default, Actors are Logged in Users. Percentage of Actors functions independently of percentage of
    time. If you enable 50% of logged in users and 25% of time, then the feature will always be enabled for 50% of actors (users)
    and occasionally enabled 25% of the time for everyone.)
end

# A contrived example of how we might use a "group"
# (a method that can be evaluated at runtime to determine feature status)
#
# Flipper.register(:first_name_is_hector) do |user|
#   user.respond_to?(:first_name) && user.first_name == 'HECTOR'
# end

Flipper::UI.configuration.feature_creation_enabled = false
# Make sure that each feature we reference in code is present in the UI, as long as we have a Database already
FLIPPER_FEATURE_CONFIG['features'].each_key do |feature|
  unless Flipper.exist?(feature)
    Flipper.add(feature)
    # default features to enabled for development and test only
    Flipper.enable(feature) if Rails.env.development? || Rails.env.test?
  end
rescue
  # make sure we can still run rake tasks before table has been created
  nil
end

# Modify Flipper::UI::Action to use custom views if they exist
# and to add descriptions for features.
Flipper::UI::Action.prepend(FlipperExtensions::ActionPatch)
