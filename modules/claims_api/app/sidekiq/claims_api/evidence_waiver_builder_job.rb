# frozen_string_literal: true

require 'claims_api/evidence_waiver_pdf/pdf'
require 'common/file_helpers'
require 'bd/bd'

module ClaimsApi
  class EvidenceWaiverBuilderJob < ClaimsApi::ServiceBase
    include ::Common::FileHelpers
    sidekiq_options expires_in: 48.hours, retry: true

    # Generate a 5103 "form" for a given veteran.
    #
    # @param evidence_waiver_id [String] Unique identifier of the submitted EWS
    def perform(evidence_waiver_id)
      lighthouse_claim = ClaimsApi::EvidenceWaiverSubmission.find(evidence_waiver_id)
      auth_headers = lighthouse_claim.auth_headers

      output_path = ClaimsApi::EvidenceWaiver.new(auth_headers:).construct

      # upload to BD
      benefits_doc_upload(claim: lighthouse_claim, pdf_path: output_path,
                          doc_type: 'L705', ptcpnt_vet_id: auth_headers['target_veteran_folder_id'])

      # with a successful upload we can set this back to pending if it errored previously
      update_status_for_submission(lighthouse_claim)

      log_ews_event(lighthouse_claim, :perform, 'Successfully uploaded benefits doc.')

      ClaimsApi::EwsUpdater.perform_async(evidence_waiver_id)
      ::Common::FileHelpers.delete_file_if_exists(output_path)
    rescue => e
      set_state_for_submission(lighthouse_claim, ClaimsApi::EvidenceWaiverSubmission::ERRORED)
      log_ews_event(lighthouse_claim, :perform, 'Job failed.', error: e.message, retry: true)
      raise e
    end

    def benefits_doc_api
      ClaimsApi::BD.new
    end

    def benefits_doc_upload(claim:, pdf_path:, doc_type:, ptcpnt_vet_id:)
      if Flipper.enabled?(:claims_api_ews_uploads_bd_refactor)
        EvidenceWaiverDocumentService.new.create_upload(claim:, pdf_path:, doc_type:, ptcpnt_vet_id:)
        log_ews_event(claim, :benefits_doc_upload,
                      'EvidenceWaiverDocumentService creation successful.')
      else
        benefits_doc_api.upload(claim:, pdf_path:, doc_type:, pctpnt_vet_id: ptcpnt_vet_id)
        log_ews_event(claim, :benefits_doc_upload, 'BD API upload successful.')
      end
    end

    def update_status_for_submission(lighthouse_claim)
      pending_state = ClaimsApi::EvidenceWaiverSubmission::PENDING

      if lighthouse_claim.status != pending_state
        set_state_for_submission(lighthouse_claim, pending_state)
        log_ews_event(lighthouse_claim, :update_status_for_submission,
                      "Status updated from #{lighthouse_claim.status} to #{pending_state}.")
      end
    end

    private

    def log_ews_event(claim, method_name, detail, **)
      ClaimsApi::Logger.log('EWS_builder',
                            evidence_waiver_submission_id: claim&.id,
                            claim_id: claim&.claim_id,
                            method: method_name,
                            detail:,
                            **)
    end
  end
end
