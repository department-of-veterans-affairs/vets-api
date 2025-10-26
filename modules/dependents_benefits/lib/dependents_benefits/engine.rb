# frozen_string_literal: true

module DependentsBenefits
  # @see https://api.rubyonrails.org/classes/Rails/Engine.html
  class Engine < ::Rails::Engine
    isolate_namespace DependentsBenefits

    config.generators.api_only = true

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    # Make sure Rails autoloads lib/ properly
    initializer :append_lib_to_autoload_paths do |_app|
      ActiveSupport::Dependencies.autoload_paths << root.join('lib')
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
