# frozen_string_literal: true

module RepresentationManagement
  class Engine < ::Rails::Engine
    isolate_namespace RepresentationManagement
    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'representation_management.autoload', before: :set_autoload_paths do |app|
      app.config.autoload_paths << Rails.root.join('modules', 'representation_management', 'lib')
    end
  end
end
