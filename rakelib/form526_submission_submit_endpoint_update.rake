# frozen_string_literal: true

require_relative '../lib/data_migrations/form526_submission_submit_endpoint_update'

namespace :form526 do
  desc 'Update submit_endpoint for all records to evss'
  task submit_endpoint_update: :environment do
    DataMigrations::Form526SubmissionSubmitEndpointUpdate.run
  end
end
