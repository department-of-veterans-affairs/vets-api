# frozen_string_literal: true

require 'flipper'
require 'flipper/adapters/active_record'
require 'active_support/cache'
require 'flipper/adapters/active_support_cache_store'

Flipper.configure do |config|
  config.default do
    activerecord_adapter = Flipper::Adapters::ActiveRecord.new
    cache = ActiveSupport::Cache::MemoryStore.new
    adapter = Flipper::Adapters::ActiveSupportCacheStore.new(activerecord_adapter, cache, expires_in: 1.minute)

    # pass adapter to handy DSL instance
    Flipper.new(adapter)
  end
end

Flipper::UI.configure do |config|
  config.percentage_of_actors.title = 'Percentage of Logged in Users'
  config.percentage_of_actors.description = %(Percentage of users functions independently of percentage of time. If you
   enable 50% of Actors and 25% of Time then the feature will always be enabled for 50% of users and occasionally
   enabled 25% of the time for everyone.)
end

# this registers a group
Flipper.register(:first_name_is_hector) do |actor|
  actor.respond_to?(:first_name) && actor.first_name == 'HECTOR'
end
