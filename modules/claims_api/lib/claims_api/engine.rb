# frozen_string_literal: true

module ClaimsApi
  class Engine < ::Rails::Engine
    isolate_namespace ClaimsApi

    initializer :append_migrations do |app|
      unless app.root.to_s.match? root.to_s
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

    initializer 'claims_api.factories', after: 'factory_bot.set_factory_paths' do
      if defined?(FactoryBot)
        path = File.expand_path('../../spec/factories', __dir__)
        FactoryBot.definition_file_paths << path
      end
    end

    initializer 'claims_api.setup_autoloader', after: :setup_main_autoloader do |app|
      Zeitwerk::Loader.new.tap do |loader|
        loader.push_dir(
          root.join('lib', 'bgs_service'),
          namespace: ClaimsApi
        )

        loader.inflector.inflect(
          # The other classes conform to standard inflection.
          'local_bgs' => 'LocalBGS'
        )

        unless app.config.cache_classes
          loader.enable_reloading
          app.config.to_prepare do
            loader.reload
          end
        end

        loader.setup
      end
    end
  end
end
