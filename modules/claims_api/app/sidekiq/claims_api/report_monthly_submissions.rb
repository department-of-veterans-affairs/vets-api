# frozen_string_literal: true

require 'claims_api/cid_mapper'

module ClaimsApi
  class ReportMonthlySubmissions < ClaimsApi::ServiceBase
    def perform
      return unless Settings.claims_api.report_enabled

      @to = Time.zone.now
      @from = 1.month.ago
      submissions = ClaimsApi::ClaimSubmission.where(created_at: @from..@to)

      ClaimsApi::SubmissionReportMailer.build(
        @from,
        @to,
        submissions
      ).deliver_now
    end
  end
end
