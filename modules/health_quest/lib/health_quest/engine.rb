# frozen_string_literal: true

require 'fhir_client'

module HealthQuest
  class Engine < ::Rails::Engine
    isolate_namespace HealthQuest
    config.generators.api_only = true

    ::FHIR.logger.level =
      if Rails.env.production?
        Logger::INFO
      else
        Logger::DEBUG
      end

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end
  end
end
