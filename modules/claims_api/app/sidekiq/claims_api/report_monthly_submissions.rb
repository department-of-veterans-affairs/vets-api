# frozen_string_literal: true

module ClaimsApi
  class ReportMonthlySubmissions < ClaimsApi::ReportingBase
    def perform
      if Settings.claims_api.report_enabled
        @to = Time.zone.now
        @from = 1.month.ago
        pact_act_data = ClaimsApi::ClaimSubmission.where(created_at: @from..@to)
        @claims_consumers = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to).pluck(:cid).uniq
        @poa_consumers = ClaimsApi::PowerOfAttorney.where(created_at: @from..@to).pluck(:cid).uniq
        @itf_consumers = ClaimsApi::IntentToFile.where(created_at: @from..@to).pluck(:cid).uniq
        @ews_consumers = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to).pluck(:cid).uniq

        ClaimsApi::SubmissionReportMailer.build(
          @from,
          @to,
          pact_act_data,
          consumer_claims_totals: claims_totals,
          poa_totals:,
          itf_totals:,
          ews_totals:
        ).deliver_now
      end
    end
  end
end
