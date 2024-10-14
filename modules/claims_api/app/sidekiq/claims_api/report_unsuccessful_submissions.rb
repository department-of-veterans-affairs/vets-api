# frozen_string_literal: true

module ClaimsApi
  class ReportUnsuccessfulSubmissions < ClaimsApi::ReportingBase
    def perform
      if Settings.claims_api.report_enabled
        @to = Time.zone.now
        @from = 1.day.ago

        ClaimsApi::UnsuccessfulReportMailer.build(
          @from,
          @to,
          consumer_claims_totals: claims_totals,
          unsuccessful_claims_submissions:,
          unsuccessful_va_gov_claims_submissions:,
          poa_totals:,
          unsuccessful_poa_submissions:,
          itf_totals:,
          ews_totals:,
          unsuccessful_evidence_waiver_submissions:
        ).deliver_now
      end
    end
  end
end
