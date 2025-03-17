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
        require_all "#{__dir__}/zero_silent_failures"
      end
    end

    initializer 'burials.pdf_fill.register_form' do |app|
      app.config.to_prepare do
        require 'pdf_fill/filler'
        require 'burials/pdf_fill/forms/va21p530ez'

        # Register our Burial Pdf Fill form
        ::PdfFill::Filler.register_form(Burials::PdfFill::Forms::Va21p530ez::FORM_ID,
                                        Burials::PdfFill::Forms::Va21p530ez)
      end
    end

    initializer 'burials.benefits_intake.register_handler' do |app|
      app.config.to_prepare do
        require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
        require 'burials/benefits_intake/submission_handler'

        # Register our Burial Benefits Intake Submission Handler
        ::BenefitsIntake::SubmissionStatusJob.register_handler(Burials::FORM_ID,
                                                               Burials::BenefitsIntake::SubmissionHandler)
      end
    end
  end
end
