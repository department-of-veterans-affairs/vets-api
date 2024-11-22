require 'load_testing/middleware/access_control'

module LoadTesting
  class Engine < ::Rails::Engine
    isolate_namespace LoadTesting

    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'spec/factories'
    end

    initializer 'load_testing.middleware' do |app|
      app.middleware.use LoadTesting::Middleware::AccessControl
    end

    # Add load testing specific configurations
    config.load_testing = ActiveSupport::OrderedOptions.new
    config.load_testing.allowed_teams = ['identity']
    config.load_testing.max_concurrent_users = 1000
    config.load_testing.token_lifetime = 30.minutes
  end
end 