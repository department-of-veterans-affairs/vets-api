# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ReportUnsuccessfulSubmissions
    include Sidekiq::Worker

    def perform
      if Settings.claims_api.report_enabled
        @to = Time.zone.now
        @from = @to.monday? ? 7.days.ago : 1.day.ago
        @consumers = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to).pluck(:source).uniq

        ClaimsApi::UnsuccessfulReportMailer.build(totals, pending, errored, @from, @to).deliver_now
      end
    end

    def errored
      ClaimsApi::AutoEstablishedClaim.where(
        created_at: @from..@to,
        status: %w[errored]
      ).order(:source, :status)
    end

    def pending
      ClaimsApi::AutoEstablishedClaim.where(
        created_at: @from..@to,
        status: 'pending'
      ).order(:source, :status)
    end

    def totals
      @consumers.map do |name|
        counts = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to, source: name).group(:status).count
        totals = counts.sum { |_k, v| v }
        error_rate = counts['errored'] ? (100.0 / totals * counts['errored']).round : 0
        if totals.positive?
          {
            name => counts.merge(totals: totals,
                                 error_rate: "#{error_rate}%")
          }
        end
      end
    end
  end
end
