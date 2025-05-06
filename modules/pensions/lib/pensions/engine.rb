# frozen_string_literal: true

module Pensions
  # @see https://api.rubyonrails.org/classes/Rails/Engine.html
  class Engine < ::Rails::Engine
    isolate_namespace Pensions
    config.generators.api_only = true

    initializer 'pensions.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'pensions.zero_silent_failures' do |app|
      app.config.to_prepare do
        require_all "#{__dir__}/zero_silent_failures"
      end
    end

    initializer 'pensions.military_information' do |app|
      app.config.to_prepare do
        require 'pensions/military_information'
      end
    end

    initializer 'pensions.pdf_fill.register_form' do |app|
      app.config.to_prepare do
        require 'pdf_fill/filler'
        require 'pensions/pdf_fill/va21p527ez'

        # Register our Pension Pdf Fill form
        ::PdfFill::Filler.register_form(Pensions::FORM_ID, Pensions::PdfFill::Va21p527ez)
      end
    end

    initializer 'pensions.benefits_intake.register_handler' do |app|
      app.config.to_prepare do
        require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
        require 'pensions/benefits_intake/submission_handler'

        # Register our Pension Benefits Intake Submission Handler
        ::BenefitsIntake::SubmissionStatusJob.register_handler(Pensions::FORM_ID,
                                                               Pensions::BenefitsIntake::SubmissionHandler)
      end
    end
  end
end
