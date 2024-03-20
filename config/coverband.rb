# frozen_string_literal: true

# config/coverband.rb NOT in the initializers
Coverband.configure do |config|
  # Do not use the $redis global variable
  config.store = Coverband::Adapters::RedisStore.new(Redis.new(url: Settings.redis.app_data.url))
  config.logger = Rails.logger

  # config options false, true. (defaults to false)
  # true and debug can give helpful and interesting code usage information
  # and is safe to use if one is investigating issues in production, but it will slightly
  # hit perf.
  # config.verbose = false

  # default false. button at the top of the web interface which clears all data
  # Kept the default to prevent data loss
  # config.web_enable_clear = true

  # default false. Experimental support for tracking view layer tracking.
  # Does not track line-level usage, only indicates if an entire file
  # is used or not.
  # config.track_views = true

  config.ignore += [
    'config/application.rb',
    'config/boot.rb',
    'config/puma.rb',
    'config/schedule.rb',
    'bin/*',
    'config/environments/*',
    'lib/tasks/*'
  ]
end
