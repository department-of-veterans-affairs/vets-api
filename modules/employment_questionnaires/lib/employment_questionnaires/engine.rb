# frozen_string_literal: true

module EmploymentQuestionnaires
  # @see https://api.rubyonrails.org/classes/Rails/Engine.html
  class Engine < ::Rails::Engine
    isolate_namespace EmploymentQuestionnaires
    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'employment_questionnaires.pdf_fill.register_form' do |app|
      app.config.to_prepare do
        require 'pdf_fill/filler'
        require 'employment_questionnaires/pdf_fill/va214140'

        # Register our Increase Compensation Pdf Fill form
        ::PdfFill::Filler.register_form(EmploymentQuestionnaires::FORM_ID, EmploymentQuestionnaires::PdfFill::Va214140)
      end
    end

    initializer 'employment_questionnaires.benefits_intake.register_handler' do |app|
      app.config.to_prepare do
        require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
        require 'employment_questionnaires/benefits_intake/submission_handler'

        # Register the Benefits Intake Submission Handler
        ::BenefitsIntake::SubmissionStatusJob.register_handler(EmploymentQuestionnaires::FORM_ID,
                                                               EmploymentQuestionnaires::BenefitsIntake::SubmissionHandler)
      end
    end
  end
end
