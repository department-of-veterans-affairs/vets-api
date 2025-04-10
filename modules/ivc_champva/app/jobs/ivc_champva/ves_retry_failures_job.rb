# frozen_string_literal: true

require 'sidekiq'
require 'pega_api/client'

# This job grabs all failed VES submissions and retries them
# After 5 attempts, it will trigger a slack notification
module IvcChampva
  class VesRetryFailuresJob
    include Sidekiq::Job

    fixtures max_attempts: 5, interval: 15.minutes

    def perform
      return unless Settings.ivc_forms.sidekiq.ves_retry_failures_job.enabled

      # Get all failed VES submissions
      failed_ves_submissions = IvcChampvaForm.where(ves_status: 'failed')

      # Retry the submissions
      failed_ves_submissions.each do |record|
        ves_client = IvcChampva::VesApi::Client.new
        ves_request = record.ves_request_data

        # TODO: make any data transformations if submissions are failing due to schema misalignments
        # can't reuse the validator because it validates `parsed_form_data`, not the final VES request
        IvcChampva::VesDataFormatter.validate_ves_request(ves_request)

        # Generate a new transaction UUID
        ves_request['transaction_uuid'] = SecureRandom.uuid

        ves_client.submit_1010d(record.transaction_uuid, 'fake-user', ves_request)
      end
    end
  end
end
