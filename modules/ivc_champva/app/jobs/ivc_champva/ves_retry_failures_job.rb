# frozen_string_literal: true

require 'sidekiq'
require 'ves_api/client'
require 'json'

# This job grabs all failed VES submissions and retries them
# After 5 attempts, it will trigger a slack notification
module IvcChampva
  class VesRetryFailuresJob
    include Sidekiq::Job

    def perform
      return unless Settings.ivc_forms.sidekiq.ves_retry_failures_job.enabled &&
                    Settings.vsp_environment != 'production'

      # Get all failed VES submissions
      failed_ves_submissions = IvcChampvaForm.where.not(ves_status: [nil, 'ok'])

      return unless failed_ves_submissions.any?

      # Send the count of forms to DataDog
      StatsD.gauge('ivc_champva.ves_submission_failures.count', failed_ves_submissions.count)

      # Retry the failed submissions
      failed_ves_submissions.each do |record|
        begin # rubocop:disable Style/RedundantBegin
          # for all records older than 5 hours, increment the StatsD counter and don't retry
          # if the failure is less than 5 hours old, retry the submission
          next if record.ves_request_data.nil?

          if record.created_at < 5.hours.ago
            StatsD.increment('ivc_champva.ves_submission_failures', tags: ["id:#{record.form_uuid}"])
          else
            resubmit_ves_request(record)
          end
        rescue => e
          Rails.logger.error("Error resubmitting VES request: #{e.message}")
          Rails.logger.error e.backtrace.join("\n")
        end
      end
    end

    def resubmit_ves_request(record)
      ves_client = IvcChampva::VesApi::Client.new
      ves_request = JSON.parse(record.ves_request_data)

      # Generate a new transaction UUID
      ves_request['transaction_uuid'] = SecureRandom.uuid

      response = ves_client.submit_1010d(ves_request['transaction_uuid'], 'fake-user', ves_request)
      ves_status = response.status == 200 ? 'ok' : response.body

      # update the database record
      record.update(
        ves_status:
      )
    end
  end
end
