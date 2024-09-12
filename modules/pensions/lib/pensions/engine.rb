# frozen_string_literal: true

module Pensions
  # @see https://api.rubyonrails.org/classes/Rails/Engine.html
  class Engine < ::Rails::Engine
    isolate_namespace Pensions
    config.generators.api_only = true

    initializer 'pensions.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'pensions.register_form' do |app|
      app.config.to_prepare do
        require 'pdf_fill/filler'
        require_relative '../pdf_fill/va21p527ez'

        # Register our Pension Pdf Fill form
        ::PdfFill::Filler.register_form(Pensions::PdfFill::Va21p527ez::FORM_ID, Pensions::PdfFill::Va21p527ez)
      end
    end
  end
end
