# frozen_string_literal: true

module IncomeAndAssets
  class Engine < ::Rails::Engine
    isolate_namespace IncomeAndAssets
    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end
  end
end
