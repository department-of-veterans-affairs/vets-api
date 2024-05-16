# frozen_string_literal: true

require 'claims_api/cid_mapper'

module ClaimsApi
  class ReportMonthlySubmissions < ClaimsApi::ServiceBase
    def perform
      return unless Settings.claims_api.report_enabled

      @to = Time.zone.now
      @from = 1.month.ago
      pact_act_data = ClaimsApi::ClaimSubmission.where(created_at: @from..@to)
      disability_compensation_count = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to).pluck(:id).uniq.size
      power_of_attorney_count = ClaimsApi::PowerOfAttorney.where(created_at: @from..@to).pluck(:id).uniq.size
      intent_to_file_count = ClaimsApi::IntentToFile.where(created_at: @from..@to).pluck(:id).uniq.size
      evidence_waiver_count = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to).pluck(:id).uniq.size

      ClaimsApi::SubmissionReportMailer.build(
        @from,
        @to,
        pact_act_data,
        disability_compensation_count,
        power_of_attorney_count,
        intent_to_file_count,
        evidence_waiver_count
      ).deliver_now
    end
  end
end
