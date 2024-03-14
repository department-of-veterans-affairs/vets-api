# frozen_string_literal: true

require 'lighthouse/benefits_documents/form526/documents_status_polling_service'
require 'lighthouse/benefits_documents/form526/update_documents_status_service'

module Lighthouse
  class Form526DocumentUploadPollingJob
    include Sidekiq::Job
    # This job runs every 24 hours
    # Only retry within that window to avoid polling the same documents twice
    # 13 retries = retry for ~17 hours
    # See Sidekiq documentation for retry algorithm
    # https://github.com/sidekiq/sidekiq/wiki/Error-Handling#automatic-job-retry
    sidekiq_options retry: 13

    POLLED_BATCH_DOCUMENT_COUNT = 100
    STATSD_KEY_PREFIX = 'worker.lighthouse.poll_form_526_document_uploads'

    sidekiq_retries_exhausted do |msg, _ex|
      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

      Rails.logger.warn(
        'Lighthouse::Form526DocumentUploadPollingJob retries exhausted',
        {
          job_id: msg['jid'],
          error_class: msg['error_class'],
          error_message: msg['error_message'],
          timestamp: Time.now.utc
        }
      )
    end

    def perform
      Lighthouse526DocumentUpload.pending.status_update_required.in_batches(
        of: POLLED_BATCH_DOCUMENT_COUNT
      ) do |document_batch|
        lighthouse_document_request_ids = document_batch.pluck(:lighthouse_document_request_id)
        response = BenefitsDocuments::Form526::DocumentsStatusPollingService.call(lighthouse_document_request_ids)
        # TODO: CATCH POLLING SERVICE TIMEOUT AND FAILURE RESPONSES

        # TODO: RESOLVING ISSUES WITH QA ENDPOINT WITH LIGHTHOUSE,
        # NEED TO ADDRESS BEFORE WE CAN RECORD VCR CASSETES FOR THESE TESTS,
        # CALLER MAY BE DIFFERENT HERE
        BenefitsDocuments::Form526::UpdateDocumentsStatusService.call(document_batch, response)

        document_batch.update_all(
          status_last_polled_at: DateTime.now
        )
      end
    end
  end
end
