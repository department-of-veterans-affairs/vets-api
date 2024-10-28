# frozen_string_literal: true

require 'data_migrations/write_benefits_intake_uuids_to_form_submission_attempts'

namespace :data_migration do
  task write_benefits_intake_uuids_to_form_submission_attempts: :environment do
    DataMigrations::WriteBenefitsIntakeUuidsToFormSubmissionAttempts.run
  end
end
