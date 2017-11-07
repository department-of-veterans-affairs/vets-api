# frozen_string_literal: true
desc 'clean up duplicate saved forms in order to add a unique index'
task saved_forms_unique_index: :environment do
  DataMigrations::UuidUniqueIndex.run
end
