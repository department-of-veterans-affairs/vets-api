# frozen_string_literal: true

module DebtsApi
  class Engine < ::Rails::Engine
    isolate_namespace DebtsApi
    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'debts_api.filter_uploaded_file_inspect' do
      ActionDispatch::Http::UploadedFile.prepend(Module.new do
        def inspect
          "#<#{self.class} [FILTERED FILE]>"
        end
      end)
    end
  end
end
