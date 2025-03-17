# frozen_string_literal: true

require 'lighthouse/benefits_documents/constants'
require 'lighthouse/benefits_documents/utilities/helpers'

module BenefitsDocuments
  class UploadStatusUpdater
    # Parses the status of a LighthouseDocumentUpload [EvidenceSubmission] submitted to Lighthouse
    # using metadata from the Lighthouse Benefits Documents API '/uploads/status' endpoint.
    # Provides methods to determine if a document has completed all steps or failed,
    # abstracting away the details of the Lighthouse status data structure.
    #
    # Additionally, updates the state of a LighthouseDocumentUpload [EvidenceSubmission] in vets-api to reflect
    # the current status of a document as it transitions from Lighthouse > VBMS > BGS
    #
    # Documentation on the Lighthouse '/uploads/status' endpoint is available here:
    # https://dev-developer.va.gov/explore/api/benefits-documents/docs?version=current

    PROCESSING_TIMEOUT_WINDOW_IN_HOURS = 24

    # @param lighthouse_document_status [Hash] includes a single document's status progress
    # after it has been submitted to Lighthouse, while Lighthouse attempts to pass it on to
    # VBMS and then BGS. These data come from Lighthouse's '/uploads/status' endpoint.
    #
    # @param pending_evidence_submission [EvidenceSubmission] the VA.gov record of the document
    # submitted to Lighthouse for tracking.
    #
    # example lighthouse_document_status hash:
    #  {
    #    "requestId": 600000001,
    #    "time": {
    #      "startTime": 1502199000,
    #      "endTime": 1502199000
    #    },
    #    "status": "IN_PROGRESS",
    #    "steps": [
    #      {
    #        "name": "BENEFITS_GATEWAY_SERVICE",
    #        "nextStepName": "BENEFITS_GATEWAY_SERVICE",
    #        "description": "string",
    #        "status": "NOT_STARTED"
    #      }
    #    ],
    #    "error": {
    #      "detail": "string",
    #      "step": "BENEFITS_GATEWAY_SERVICE"
    #    }
    #  }
    #

    def self.call(*)
      new(*).update_status
    end

    def initialize(lighthouse_document_status_response, pending_evidence_submission)
      @lighthouse_document_status_response = lighthouse_document_status_response
      @pending_evidence_submission = pending_evidence_submission
    end

    def update_status
      # Only save an upload's status if it has transitioned since the last Lighthouse poll
      return unless status_changed?

      process_failure if failed?

      process_upload if completed?

      log_status
    end

    private

    def status_changed?
      if @lighthouse_document_status_response['status'] != @pending_evidence_submission.upload_status
        ::Rails.logger.info(
          'LH - Status changed',
          old_status: @pending_evidence_submission.upload_status,
          status: @lighthouse_document_status_response['status'],
          status_response: @lighthouse_document_status_response,
          evidence_submission_id: @pending_evidence_submission.id,
          claim_id: @pending_evidence_submission.claim_id
        )
      end
      @lighthouse_document_status_response['status'] != @pending_evidence_submission.upload_status
    end

    def failed?
      @lighthouse_document_status_response['status'] == BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED]
    end

    def completed?
      @lighthouse_document_status_response['status'] == BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS]
    end

    def log_status
      ::Rails.logger.info(
        'BenefitsDocuments::UploadStatusUpdater',
        status: @lighthouse_document_status_response['status'],
        status_response: @lighthouse_document_status_response,
        updated_at: DateTime.now.utc,
        evidence_submission_id: @pending_evidence_submission.id,
        claim_id: @pending_evidence_submission.claim_id
      )
    end

    def process_failure
      @pending_evidence_submission.update!(
        upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:FAILED],
        failed_date: DateTime.now.utc,
        acknowledgement_date: (DateTime.current + 30.days),
        error_message: @lighthouse_document_status_response['error'],
        template_metadata: {
          personalisation: update_personalisation
        }.to_json
      )
    end

    # Update personalisation here since an evidence submission record was previously created
    def update_personalisation
      personalisation = JSON.parse(@pending_evidence_submission.template_metadata)['personalisation'].clone
      personalisation['date_failed'] = BenefitsDocuments::Utilities::Helpers.format_date_for_mailers(DateTime.current)
      personalisation
    end

    def process_upload
      @pending_evidence_submission.update!(
        upload_status: BenefitsDocuments::Constants::UPLOAD_STATUS[:SUCCESS],
        delete_date: (DateTime.current + 60.days)
      )
    end
  end
end
