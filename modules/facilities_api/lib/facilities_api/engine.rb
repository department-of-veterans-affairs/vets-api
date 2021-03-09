# frozen_string_literal: true

module FacilitiesApi
  class Engine < ::Rails::Engine
    isolate_namespace FacilitiesApi

    config.generators do |g|
      g.api_only = true
      g.test_framework :rspec, view_specs: false
      g.fixture_replacement :factory_bot
      g.factory_bot dir: 'spec/factories'
    end

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end
  end
end
