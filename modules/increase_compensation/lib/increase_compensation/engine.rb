# frozen_string_literal: true

module IncreaseCompensation
  # @see https://api.rubyonrails.org/classes/Rails/Engine.html
  class Engine < ::Rails::Engine
    isolate_namespace IncreaseCompensation
    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'increase_compensation.pdf_fill.register_form' do |app|
      app.config.to_prepare do
        require 'pdf_fill/filler'
        require 'increase_compensation/pdf_fill/va218940v1'

        # Register our Increase Compensation Pdf Fill form
        ::PdfFill::Filler.register_form(IncreaseCompensation::FORM_ID, IncreaseCompensation::PdfFill::Va218940v1)
      end
    end

    initializer 'increase_compensation.benefits_intake.register_handler' do |app|
      app.config.to_prepare do
        require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
        require 'increase_compensation/benefits_intake/submission_handler'

        # Register the Benefits Intake Submission Handler
        ::BenefitsIntake::SubmissionStatusJob.register_handler(
          IncreaseCompensation::FORM_ID,
          IncreaseCompensation::BenefitsIntake::SubmissionHandler
        )
      end
    end
  end
end
