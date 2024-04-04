require 'data_migrations/personal_information_log_data_update'

namespace :data_migration do
  task personal_information_log_data_update: :environment do
    DataMigrations::PersonalInformationLogDataUpdate.run
  end
end
