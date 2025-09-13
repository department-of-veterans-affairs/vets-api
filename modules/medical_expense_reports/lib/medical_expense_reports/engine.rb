# frozen_string_literal: true

module MedicalExpenseReports
  # @see https://api.rubyonrails.org/classes/Rails/Engine.html
  class Engine < ::Rails::Engine
    isolate_namespace MedicalExpenseReports
    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'medical_expense_reports.pdf_fill.register_form' do |app|
      app.config.to_prepare do
        require 'pdf_fill/filler'
        require 'medical_expense_reports/pdf_fill/va21p8416'

        # Register our Medical Expense Reports Pdf Fill form
        ::PdfFill::Filler.register_form(MedicalExpenseReports::FORM_ID, MedicalExpenseReports::PdfFill::Va21p8416)
      end
    end

    initializer 'medical_expense_reports.benefits_intake.register_handler' do |app|
      app.config.to_prepare do
        require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
        require 'medical_expense_reports/benefits_intake/submission_handler'

        # Register the Benefits Intake Submission Handler
        ::BenefitsIntake::SubmissionStatusJob.register_handler(MedicalExpenseReports::FORM_ID,
                                                               MedicalExpenseReports::BenefitsIntake::SubmissionHandler)
      end
    end
  end
end
