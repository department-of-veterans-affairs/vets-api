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
    def perform(evidence_waiver_id, _claim)
      lighthouse_claim = ClaimsApi::EvidenceWaiverSubmission.find(evidence_waiver_id)
      auth_headers = lighthouse_claim.auth_headers
      output_path = ClaimsApi::EvidenceWaiver.new(auth_headers:).construct

      # upload to BD
      benefits_doc_api.upload(claim: lighthouse_claim, pdf_path: output_path,
                              doc_type: 'L705')
      ClaimsApi::EwsUpdater.perform_async(evidence_waiver_id)
      ::Common::FileHelpers.delete_file_if_exists(output_path)
    rescue VBMS::ClientError => e
      rescue_invalid_filename(lighthouse_claim, e)
    rescue VBMS::Unknown
      rescue_vbms_error(lighthouse_claim)
      raise VBMS::Unknown # for sidekiq retries
    rescue Errno::ENOENT
      rescue_file_not_found(lighthouse_claim)
    end

    def benefits_doc_api
      ClaimsApi::BD.new
    end
  end
end
