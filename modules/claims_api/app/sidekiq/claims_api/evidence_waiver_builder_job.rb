# frozen_string_literal: true

require 'claims_api/ews_vbms_sidekiq'
require 'claims_api/evidence_waiver_pdf/pdf'
require 'bd/bd'

module ClaimsApi
  class EvidenceWaiverBuilderJob < ClaimsApi::ServiceBase
    include ClaimsApi::EwsVBMSSidekiq

    # Generate a 5103 "form" for a given veteran.
    #
    # @param evidence_waiver_id [String] Unique identifier of the submitted EWS
    def perform(evidence_waiver_id, claim)
      evidence_waiver_submission = ClaimsApi::EvidenceWaiverSubmission.find(evidence_waiver_id)
      auth_headers = evidence_waiver_submission.auth_headers
      output_path = ClaimsApi::EvidenceWaiver.new(auth_headers:).construct

      # upload to BD
      benefits_doc_api.upload(claim:, pdf_path: output_path, ews: evidence_waiver_submission)
      ClaimsApi::EwsUpdater.perform_async(evidence_waiver_id)

      ::Common::FileHelpers.delete_file_if_exists(output_path)
    rescue VBMS::ClientError => e
      rescue_invalid_filename(evidence_waiver_submission, e)
    rescue VBMS::Unknown
      rescue_vbms_error(evidence_waiver_submission)
      raise VBMS::Unknown # for sidekiq retries
    rescue Errno::ENOENT
      rescue_file_not_found(evidence_waiver_submission)
    end

    def benefits_doc_api
      ClaimsApi::BD.new
    end
  end
end
