# frozen_string_literal: true

module AccreditedRepresentativePortal
  class Engine < ::Rails::Engine
    isolate_namespace AccreditedRepresentativePortal

    # `isolate_namespace` redefines `table_name_prefix` on load of
    # `active_record`, so we append our own callback to redefine it again how we
    # want.
    ActiveSupport.on_load(:active_record) do
      AccreditedRepresentativePortal.redefine_singleton_method(:table_name_prefix) do
        'ar_'
      end
    end

    config.generators.api_only = true

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

    initializer 'model_core.factories', after: 'factory_bot.set_factory_paths' do
      FactoryBot.definition_file_paths << File.expand_path('../../spec/factories', __dir__) if defined?(FactoryBot)
    end

    initializer 'accredited_representative_portal.benefits_intake.register_handler',
                after: :append_lib_to_autoload_paths do |app|
      app.config.to_prepare do
        require 'lighthouse/benefits_intake/sidekiq/submission_status_job'
        require 'accredited_representative_portal/submission_handler'

        AccreditedRepresentativePortal::SavedClaim::BenefitsIntake::FORM_TYPES.each do |form_class|
          ::BenefitsIntake::SubmissionStatusJob.register_handler(
            form_class::FORM_ID,
            AccreditedRepresentativePortal::SubmissionHandler
          )
        end
      end
    end
  end
end
