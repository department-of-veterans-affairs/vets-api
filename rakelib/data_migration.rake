# frozen_string_literal: true

namespace :data_migration do
  task in_progress_form_initial_expiration: :environment do
    rows_affected = DataMigrations::InProgressFormInitialExpiration.run
    puts "Total rows affected for expiration date updates: #{rows_affected}"
  end
end
