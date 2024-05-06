# frozen_string_literal: true

require 'claims_api/cid_mapper'

module ClaimsApi
  class ReportMonthlySubmissions < ClaimsApi::ServiceBase
    def perform
      return unless Settings.claims_api.report_enabled

      @to = Time.zone.now
      @from = 1.month.ago
      pact_act_claims = ClaimsApi::ClaimSubmission.where(created_at: @from..@to)
      disability_compensation_claims = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to)
      power_of_attorney = ClaimsApi::PowerOfAttorney.where(created_at: @from..@to)
      intent_to_file = ClaimsApi::IntentToFile.where(created_at: @from..@to)
      evidence_waiver = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to)

      ClaimsApi::SubmissionReportMailer.build(
        @from,
        @to,
        disability_compensation_claims,
        pact_act_claims,
        power_of_attorney,
        intent_to_file,
        evidence_waiver
      ).deliver_now
    end
  end
end
