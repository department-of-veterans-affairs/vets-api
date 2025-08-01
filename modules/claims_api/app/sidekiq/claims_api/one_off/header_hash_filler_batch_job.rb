# frozen_string_literal: true

require 'claims_api/claim_logger'

module ClaimsApi::OneOff
  class HeaderHashFillerBatchJob < ClaimsApi::ServiceBase
    sidekiq_options retry: false
    LOG_TAG = 'header_hash_filler_batch_job'
    SINGLE_RUN_SIZE = 750 # The number of records to process per batch. See HeaderHashFillerJob for why.

    def perform
      unless Flipper.enabled? :lighthouse_claims_api_run_header_hash_filler_job
        log level: :warn, details: 'Feature flag is disabled for header hash filling'
        return
      end

      counts = { poas: ClaimsApi::PowerOfAttorney.where(header_hash: nil).count,
                 aecs: ClaimsApi::AutoEstablishedClaim.where(header_hash: nil).count }

      if counts[:poas].zero? && counts[:aecs].zero?
        notify_batches_finished
        return
      end

      log details: "Remaining blank header_hash records - POAs: #{counts[:poas]}, AECs: #{counts[:aecs]}"

      enqueue_jobs 'ClaimsApi::PowerOfAttorney', counts[:poas] if counts[:poas].positive?
      enqueue_jobs 'ClaimsApi::AutoEstablishedClaim', counts[:aecs], 2 if counts[:aecs].positive?
    rescue => e
      log level: :error,
          details: 'Failed to enqueue jobs for header hash filling',
          error_class: e.class.name,
          error_message: e.message
    end

    # Sets up jobs to run every 5 mins for the next hour. Is public so it can be called from the Rails console
    # Ignores the feature flag, so it can be used to backfill header hashes manually if needed
    # @param model_str [String] The model class name as a string, e.g. 'ClaimsApi::PowerOfAttorney'
    # @param count [Integer] The number of records to process in total
    # @param delay [Integer] Delay in mins before queue starts. Used to stagger job starts between models
    def enqueue_jobs(model_str, count, delay = 0)
      total_batches = (count / SINGLE_RUN_SIZE.to_f).ceil
      total_batches = 10 if total_batches > 10 # Limit to 10 batches to load up runs for ~50 mins

      total_batches.times do |i|
        ClaimsApi::OneOff::HeaderHashFillerJob.perform_in(delay.minutes + (i * 5.minutes), model_str)
      end
    end

    private

    def log(**)
      ClaimsApi::Logger.log(LOG_TAG, **)
    end

    def notify_batches_finished
      msg = 'No records left to process for header hash filling.'
      log details: msg
      slack_alert_on_failure(LOG_TAG, msg) # Not really a failure, but we want to notify
    end
  end
end
