# frozen_string_literal: true

require 'lighthouse/benefits_documents/form526/documents_status_polling_service'
require 'lighthouse/benefits_documents/form526/update_documents_status_service'

module Lighthouse
  class Form526DocumentUploadPollingJob
    include Sidekiq::Job
    # Job runs every hour; ensure retries happen within the same window to prevent duplicate polling of documents
    # 7 retries = retry for ~42 minutes
    # See Sidekiq documentation for exponential retry formula:
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling#automatic-job-retry
    sidekiq_options retry: 7

    POLLED_BATCH_DOCUMENT_COUNT = 100
    STATSD_KEY_PREFIX = 'worker.lighthouse.poll_form526_document_uploads'
    STATSD_PENDING_DOCUMENTS_POLLED_KEY = 'pending_documents_polled'
    STATSD_PENDING_DOCUMENTS_MARKED_SUCCESS_KEY = 'pending_documents_marked_completed'
    STATSD_PENDING_DOCUMENTS_MARKED_FAILED_KEY = 'pending_documents_marked_failed'

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']

      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

      Rails.logger.warn(
        'Lighthouse::Form526DocumentUploadPollingJob retries exhausted',
        { job_id:, error_class:, error_message:, timestamp: Time.now.utc }
      )
    rescue => e
      Rails.logger.error(
        'Failure in Form526DocumentUploadPollingJob#sidekiq_retries_exhausted',
        {
          messaged_content: e.message,
          job_id:,
          pre_exhaustion_failure: {
            error_class:,
            error_message:
          }
        }
      )
    end

    def perform
      successful_documents_before_polling = Lighthouse526DocumentUpload.completed.count
      failed_documents_before_polling = Lighthouse526DocumentUpload.failed.count

      documents_to_poll = Lighthouse526DocumentUpload.pending.status_update_required
      StatsD.gauge("#{STATSD_KEY_PREFIX}.#{STATSD_PENDING_DOCUMENTS_POLLED_KEY}", documents_to_poll.count)

      documents_to_poll.in_batches(
        of: POLLED_BATCH_DOCUMENT_COUNT
      ) do |document_batch|
        lighthouse_document_request_ids = document_batch.pluck(:lighthouse_document_request_id)

        update_document_batch(document_batch, lighthouse_document_request_ids)
      rescue Faraday::ResourceNotFound => e
        response_struct = OpenStruct.new(e.response)

        handle_error(response_struct, lighthouse_document_request_ids)
      end

      documents_marked_success = Lighthouse526DocumentUpload.completed.count - successful_documents_before_polling
      StatsD.gauge("#{STATSD_KEY_PREFIX}.#{STATSD_PENDING_DOCUMENTS_MARKED_SUCCESS_KEY}", documents_marked_success)

      documents_marked_failed = Lighthouse526DocumentUpload.failed.count - failed_documents_before_polling
      StatsD.gauge("#{STATSD_KEY_PREFIX}.#{STATSD_PENDING_DOCUMENTS_MARKED_FAILED_KEY}", documents_marked_failed)
    end

    private

    def update_document_batch(document_batch, lighthouse_document_request_ids)
      response = BenefitsDocuments::Form526::DocumentsStatusPollingService.call(lighthouse_document_request_ids)

      if response.status == 200
        result = BenefitsDocuments::Form526::UpdateDocumentsStatusService.call(document_batch, response.body)

        if result && !result[:success]
          response_struct = OpenStruct.new(result[:response])

          handle_error(response_struct, response_struct.unknown_ids.map(&:to_s))
        end
      else
        handle_error(response, lighthouse_document_request_ids)
      end
    end

    def handle_error(response, lighthouse_document_request_ids)
      StatsD.increment("#{STATSD_KEY_PREFIX}.polling_error")

      Rails.logger.warn(
        'Lighthouse::Form526DocumentUploadPollingJob status endpoint error',
        {
          response_status: response.status,
          response_body: response.body,
          lighthouse_document_request_ids:,
          timestamp: Time.now.utc
        }
      )
    end
  end
end
