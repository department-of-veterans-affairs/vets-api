# frozen_string_literal: true

module DependentsBenefits
  # @see https://api.rubyonrails.org/classes/Rails/Engine.html
  class Engine < ::Rails::Engine
    isolate_namespace DependentsBenefits

    config.generators.api_only = true

    # Make sure Rails eager loads lib/ properly for this engine.
    # CRITICAL for Sidekiq jobs: When Sidekiq retries jobs asynchronously (minutes/hours/days later),
    # it deserializes the job class name from Redis and needs to constantize it. If lib/ isn't in
    # the eager load paths, Zeitwerk won't load classes like DependentsBenefits::BGS::BGSFormJob
    # when the retry worker attempts to process the job, causing NameError and permanent job failures.
    # This is especially important because retries often happen in different processes or after restarts.
    config.eager_load_paths << root.join('lib').to_s

    initializer 'dependents_benefits.zeitwerk_ignore' do
      # Zeitwerk expects version.rb to define a Version class/module, but we use VERSION constant per Ruby convention.
      # Tell Zeitwerk to ignore this file to avoid "uninitialized constant DependentsBenefits::Version" errors.
      Rails.autoloaders.main.ignore(root.join('lib/dependents_benefits/version.rb'))
    end

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    # So that the app-wide migration command notices our engine's migrations.
    initializer :append_migrations do |app|
      unless app.root.to_s.match? root.to_s
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
          ActiveRecord::Migrator.migrations_paths << expanded_path
        end
      end
    end

    initializer 'dependents_benefits.benefits_intake.register_handler' do |app|
      app.config.to_prepare do
        require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
        require 'dependents_benefits/benefits_intake/submission_handler'

        # Register our Pension Benefits Intake Submission Handler
        ::BenefitsIntake::SubmissionStatusJob.register_handler(DependentsBenefits::FORM_ID_V2,
                                                               DependentsBenefits::BenefitsIntake::SubmissionHandler)
      end
    end
  end
end
