# frozen_string_literal: true

namespace :data_migration do
  task write_benefits_intake_uuids_to_form_submission_attempts: :environment do
    DataMigrations::WriteBenefitsIntakeUuidsToFormSubmissionAttempts.run
  end
end
