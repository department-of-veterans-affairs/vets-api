require_relative 'boot'

# Only require the frameworks we need
require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'active_job/railtie'
require 'rails/test_unit/railtie'

# Require the gems listed in Gemfile
Bundler.require(*Rails.groups)

# Only require our engine
require 'load_testing'

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f

    # Settings in config/environments/* take precedence over those specified here.
    config.api_only = true
    
    # Use test configuration
    config.eager_load = false
    
    # Prevent database truncation if the environment is production
    abort("The Rails environment is running in production mode!") if Rails.env.production?

    # Minimal logging for tests
    config.log_level = :warn
    config.active_support.deprecation = :stderr
    
    # Don't load main app files
    config.paths.add "config/database", with: "config/database.yml"
    config.paths["config/initializers"] = []
    config.paths["config/environment"] = ["config/environment.rb"]
    
    # Disable main app autoloading
    def add_autoload_paths_to_load_path
      # Do nothing - prevent autoloading main app
    end
  end
end 