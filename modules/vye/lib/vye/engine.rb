# frozen_string_literal: true

module Vye
  class Vye::Engine < Rails::Engine
    isolate_namespace Vye
    config.generators.api_only = true
    config.autoload_paths << (root / 'lib')

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << (root / 'spec/factories') if defined?(FactoryBot)
    end
  end
end
