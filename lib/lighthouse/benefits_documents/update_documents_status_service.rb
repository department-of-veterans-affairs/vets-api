# frozen_string_literal: true

require 'lighthouse/benefits_documents/documents_status_polling_service'
require 'lighthouse/benefits_documents/upload_status_updater'

module BenefitsDocuments
  class UpdateDocumentsStatusService
    def self.call(*)
      new(*).process_status_updates
    end

    # @param pending_evidence_submission_batch - EvidenceSubmission records with a upload_status of PENDING
    # EvidenceSubmission records polled for status updates on Lighthouse's '/uploads/status' endpoint
    # @param lighthouse_status_response [Hash] the parsed JSON response body from the endpoint
    def initialize(pending_evidence_submission_batch, lighthouse_status_response)
      @pending_evidence_submission_batch = pending_evidence_submission_batch
      @lighthouse_status_response = lighthouse_status_response
    end

    def process_status_updates
      update_documents_status
      unknown_ids = @lighthouse_status_response.dig('data', 'requestIdsNotFound')

      return { success: true } if unknown_ids.blank?

      Rails.logger.warn(
        'Benefits Documents API cannot find these requestIds and cannot verify upload status', {
          request_ids: unknown_ids
        }
      )
      { success: false, response: { status: 404, body: 'Upload Request Async Status Not Found', unknown_ids: } }
    end

    private

    # Loop through each status response that lighthouse returned and use the request Id in the status response to
    # find the given PENDING evidence submission record. Then we call BenefitsDocuments::UploadStatusUpdater
    # to update the PENDING evidence submission record accordingly.
    def update_documents_status
      @lighthouse_status_response.dig('data', 'statuses').each do |status_response|
        pending_evidence_submission = @pending_evidence_submission_batch.find_by!(
          request_id: status_response['requestId']
        )
        BenefitsDocuments::UploadStatusUpdater.call(status_response, pending_evidence_submission)
      end
    end
  end
end
