# frozen_string_literal: true

module HealthQuest
  class Engine < ::Rails::Engine
    isolate_namespace HealthQuest
    config.generators.api_only = true
    if Rails.env.development?
      config.autoload_paths << File.expand_path('../../app/policies', __FILE__)
      config.autoload_paths << File.expand_path('../../app/services/health_quest/middleware', __FILE__)
      config.autoload_paths << File.expand_path('../../app/services/health_quest/middleware/response', __FILE__)
    end  

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end
  end
end