# frozen_string_literal: true

namespace :data_migration do
  task in_progress_forms_status: :environment do
    DataMigrations::InProgressFormStatusDefault.run
  end
end
