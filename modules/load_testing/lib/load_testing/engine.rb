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

    # Add migrations path
    initializer :append_migrations do |app|
      unless app.root.to_s.match?(root.to_s)
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
        end
      end
    end

    # Add load testing specific configurations
    config.load_testing = ActiveSupport::OrderedOptions.new
    config.load_testing.allowed_teams = ['identity']
    config.load_testing.max_concurrent_users = 1000
    config.load_testing.token_lifetime = 30.minutes

    # Add this line to ensure jobs are loaded
    config.autoload_paths += %W[#{config.root}/app/jobs]

    config.autoload_paths += %W[
      #{config.root}/lib
      #{config.root}/lib/load_testing/authentication
    ]

    initializer 'load_testing.authentication' do |app|
      require_relative 'authentication/service_retriever'
      require_relative 'authentication/logingov'

      # Register the Logingov authentication service
      LoadTesting::Authentication::ServiceRetriever.register_service('logingov', LoadTesting::Authentication::Logingov)
    end
  end
end 