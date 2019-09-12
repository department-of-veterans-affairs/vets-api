# frozen_string_literal: true

require 'flipper'
require 'flipper/adapters/active_record'
require 'active_support/cache'
require 'flipper/adapters/active_support_cache_store'

# Add new Feature toggles here.  They will be off until toggled int the UI
FLIPPER_FEATURES = ['profile_show_direct_deposit'].freeze

# Flipper settings will be stored in postgres and cached in memory for 1 minute
Flipper.configure do |config|
  config.default do
    activerecord_adapter = Flipper::Adapters::ActiveRecord.new
    cache = ActiveSupport::Cache::MemoryStore.new
    adapter = Flipper::Adapters::ActiveSupportCacheStore.new(activerecord_adapter, cache, expires_in: 1.minute)

    # pass adapter to handy DSL instance
    Flipper.new(adapter)
  end
end

# Labeling what flipper calls "actors" as "users" in the UI
Flipper::UI.configure do |config|
  config.percentage_of_actors.title = 'Percentage of Logged in Users'
  config.percentage_of_actors.description = %(Percentage of users functions independently of percentage of time.
    If you enable 50% of Actors and 25% of Time then the feature will always be enabled for 50% of users and
    occasionally enabled 25% of the time for everyone.)
end

# A contrived example of how we might use a "group"
# (a method that can be evaluated at runtime to determine feature status)
#
# Flipper.register(:first_name_is_hector) do |user|
#   user.respond_to?(:first_name) && user.first_name == 'HECTOR'
# end

# Make sure that each feature we reference in code is present in the UI
# will default to disabled.
FLIPPER_FEATURES.each do |service|
  Flipper.add(service) unless Flipper.exist?(service)
end
