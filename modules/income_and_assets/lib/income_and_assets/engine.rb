# frozen_string_literal: true

module IncomeAndAssets
  # @see https://api.rubyonrails.org/classes/Rails/Engine.html
  class Engine < ::Rails::Engine
    isolate_namespace IncomeAndAssets
    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'income_and_assets.pdf_fill.register_form' do |app|
      app.config.to_prepare do
        require 'pdf_fill/filler'
        require 'income_and_assets/pdf_fill/va21p0969'

        # Register our Income and Assets Pdf Fill form
        ::PdfFill::Filler.register_form(IncomeAndAssets::FORM_ID, IncomeAndAssets::PdfFill::Va21p0969)
      end
    end

    initializer 'income_and_assets.benefits_intake.register_handler' do |app|
      app.config.to_prepare do
        require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
        require 'income_and_assets/benefits_intake/submission_handler'

        # Register the Benefits Intake Submission Handler
        ::BenefitsIntake::SubmissionStatusJob.register_handler(IncomeAndAssets::FORM_ID,
                                                               IncomeAndAssets::BenefitsIntake::SubmissionHandler)
      end
    end
  end
end
