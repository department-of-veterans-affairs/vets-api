# require 'pdf_fill/filler'

# frozen_string_literal: true

module Pensions
  class Engine < ::Rails::Engine
    isolate_namespace Pensions
    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'pensions.after_initialize' do |app|
      app.config.after_initialize do
        # Your code to run after the application has started
        # For example, calling a registration function
        PdfFill::Filler.register_form('21P-527EZ', PdfFill::Forms::Va21p527ez)
      end
    end
  end
end
