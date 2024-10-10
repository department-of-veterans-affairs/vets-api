# frozen_string_literal: true

module Burials
  # @see https://api.rubyonrails.org/classes/Rails/Engine.html
  class Engine < ::Rails::Engine
    isolate_namespace Burials
    config.generators.api_only = true

    initializer 'burials.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'burials.zero_silent_failures' do |app|
      app.config.to_prepare do
        require_all "#{__dir__}/../zero_silent_failures"
      end
    end

    # TODO: move PDFFill library to this module
    # initializer 'burials.register_form' do |app|
    #   app.config.to_prepare do
    #     require 'pdf_fill/filler'
    #     require_relative '../pdf_fill/va21p530v2'

    #     # Register our Burial Pdf Fill form
    #     ::PdfFill::Filler.register_form(Burials::PdfFill::Va21p530v2::FORM_ID, Burials::PdfFill::Va21p530v2)
    #   end
    # end
  end
end
