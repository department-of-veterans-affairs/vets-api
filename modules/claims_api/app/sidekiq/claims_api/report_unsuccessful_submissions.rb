# frozen_string_literal: true

module ClaimsApi
  class ReportUnsuccessfulSubmissions < ClaimsApi::ReportingBase
    include ClaimsApi::ReportRecipientsReader

    def perform
      if Settings.claims_api.report_enabled
        @to = Time.zone.now
        @from = 1.day.ago

        recipients = load_recipients('unsuccessful_report_mailer')
        return if recipients.empty?

        ClaimsApi::UnsuccessfulReportMailer.build(
          @from,
          @to,
          recipients,
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
