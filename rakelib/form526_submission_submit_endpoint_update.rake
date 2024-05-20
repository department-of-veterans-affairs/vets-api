# frozen_string_literal: true

namespace :form526 do
  desc 'Update submit_endpoint for all records to evss'
  task submit_endpoint_update: :environment do
    DataMigrations::Form526SubmissionSubmitEndpointUpdate.run
  end
end
