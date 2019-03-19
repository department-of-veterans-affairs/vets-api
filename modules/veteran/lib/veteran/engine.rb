# frozen_string_literal: true

module Veteran
  class Engine < ::Rails::Engine
    isolate_namespace Veteran

    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
          ActiveRecord::Migrator.migrations_paths << expanded_path
        end
      end
    end

    config.generators do |g|
      g.test_framework :rspec, view_specs: false
      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'spec/factories'
    end

    initializer 'veteran.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../../spec/factories', __FILE__) if defined?(FactoryBot)
    end
  end
end
