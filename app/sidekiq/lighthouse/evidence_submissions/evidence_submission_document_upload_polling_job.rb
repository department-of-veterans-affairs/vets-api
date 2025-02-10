# frozen_string_literal: true

require 'lighthouse/benefits_documents/documents_status_polling_service'
require 'lighthouse/benefits_documents/update_documents_status_service'

module Lighthouse
  module EvidenceSubmissions
    class EvidenceSubmissionDocumentUploadPollingJob
      include Sidekiq::Job
      # Job runs every hour; ensure retries happen within the same window to prevent duplicate polling of documents
      # 7 retries = retry for ~42 minutes
      # See Sidekiq documentation for exponential retry formula:
      # https://github.com/sidekiq/sidekiq/wiki/Error-Handling#automatic-job-retry
      sidekiq_options retry: 7

      POLLED_BATCH_DOCUMENT_COUNT = 100
      # STATSD_KEY_PREFIX = ''

      sidekiq_retries_exhausted do |msg, _ex|
        job_id = msg['jid']
        error_class = msg['error_class']
        error_message = msg['error_message']

        # TODO: Add statsD
        # StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

        Rails.logger.warn(
          'Lighthouse::EvidenceSubmissions::EvidenceSubmissionDocumentUploadPollingJob retries exhausted',
          { job_id:, error_class:, error_message:, timestamp: Time.now.utc }
        )
      rescue => e
        Rails.logger.error(
          'Failure in
          Lighthouse::EvidenceSubmissions::EvidenceSubmissionDocumentUploadPollingJob#sidekiq_retries_exhausted',
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
        pending_evidence_submissions = EvidenceSubmission.pending

        pending_evidence_submissions.in_batches(
          of: POLLED_BATCH_DOCUMENT_COUNT
        ) do |pending_evidence_submission_batch|
          lighthouse_document_request_ids = pending_evidence_submission_batch.pluck(:request_id)

          update_batch(pending_evidence_submission_batch, lighthouse_document_request_ids)
        rescue Faraday::ResourceNotFound => e
          response_struct = OpenStruct.new(e.response)

          handle_error(response_struct, lighthouse_document_request_ids)
        end
      end

      private

      # This method does the following:
      # Calls BenefitsDocuments::DocumentsStatusPollingService which makes a post call to
      # Lighthouse to get the staus of the document upload
      # Calls BenefitsDocuments::UpdateDocumentsStatusService when the call to lighthouse was successful
      # and updates each evidence_submission record in the batch with the status that lighthouse returned
      def update_batch(pending_evidence_submission_batch, lighthouse_document_request_ids)
        response = BenefitsDocuments::DocumentsStatusPollingService.call(lighthouse_document_request_ids)

        if response.status == 200
          result = BenefitsDocuments::UpdateDocumentsStatusService.call(
            pending_evidence_submission_batch, response.body
          )

          if result && !result[:success]
            response_struct = OpenStruct.new(result[:response])

            handle_error(response_struct, response_struct.unknown_ids.map(&:to_s))
          end
        else
          handle_error(response, lighthouse_document_request_ids)
        end
      end

      def handle_error(response, lighthouse_document_request_ids)
        Rails.logger.warn(
          'Lighthouse::EvidenceSubmissionDocumentUploadPollingJob status endpoint error',
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
end
