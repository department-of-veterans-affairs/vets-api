# frozen_string_literal: true

module DependentsVerification
  # @see https://api.rubyonrails.org/classes/Rails/Engine.html
  class Engine < ::Rails::Engine
    isolate_namespace DependentsVerification
    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'dependents_verification.pdf_fill.register_form' do |app|
      app.config.to_prepare do
        require 'pdf_fill/filler'
        require 'dependents_verification/pdf_fill/va210538'

        # Register our DependentsVerification Pdf Fill form
        ::PdfFill::Filler.register_form(DependentsVerification::PdfFill::Va210538::FORM_ID,
                                        DependentsVerification::PdfFill::Va210538)
      end
    end
  end
end
