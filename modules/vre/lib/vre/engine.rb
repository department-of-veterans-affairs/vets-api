# frozen_string_literal: true

module VRE
  class Engine < ::Rails::Engine
    isolate_namespace VRE
    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'vre.autoload', before: :set_autoload_paths do |app|
      app.config.autoload_paths << Rails.root.join('modules', 'vre', 'lib')
    end
  end
end
