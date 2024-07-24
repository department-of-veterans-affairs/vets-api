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
      benefits_doc_api.upload(claim: lighthouse_claim, pdf_path: output_path,
                              doc_type: 'L705', pctpnt_vet_id: auth_headers['target_veteran_folder_id'])
      ClaimsApi::EwsUpdater.perform_async(evidence_waiver_id)
      ::Common::FileHelpers.delete_file_if_exists(output_path)
    rescue => e
      ClaimsApi::Logger.log('EWS_builder', retry: true, detail: 'failed to upload to BD')
      raise e
    end

    def benefits_doc_api
      ClaimsApi::BD.new
    end
  end
end
