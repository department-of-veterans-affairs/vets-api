# frozen_string_literal: true

require 'pensions/data_migrations/saved_claims_form_start_date_update'

# TODO: Remove this file after the migration has been run
namespace :data_migration do
  desc 'Migrate data from deprecated itf_datetime column to form_start_date'
  task saved_claims_form_start_date_update: :environment do
    Pensions::DataMigrations::SavedClaimsFormStartDateUpdate.run
  end
end
