# frozen_string_literal: true

require 'sidekiq'
require 'claims_api/ews_vbms_sidekiq'
require 'claims_api/evidence_waiver_pdf/pdf'

module ClaimsApi
  class EvidenceWaiverBuilderJob
    include Sidekiq::Worker
    include ClaimsApi::EwsVBMSSidekiq

    # Generate a 5103 "form" for a given veteran.
    #
    # @param evidence_waiver_id [String] Unique identifier of the submitted EWS
    def perform(evidence_waiver_id)
      evidence_waiver_submission = ClaimsApi::EvidenceWaiverSubmission.find(evidence_waiver_id)
      auth_headers = evidence_waiver_submission.auth_headers
      output_path = ClaimsApi::EvidenceWaiver.new(auth_headers:).construct

      upload_to_vbms(evidence_waiver_submission, output_path)
      ClaimsApi::EwsUpdater.perform_async(evidence_waiver_id)

      ::Common::FileHelpers.delete_file_if_exists(output_path)
    rescue VBMS::Unknown
      rescue_vbms_error(evidence_waiver_submission)
    rescue Errno::ENOENT
      rescue_file_not_found(evidence_waiver_submission)
    end
  end
end
