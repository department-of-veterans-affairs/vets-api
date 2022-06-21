# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ReportUnsuccessfulSubmissions
    include Sidekiq::Worker

    def perform
      if Settings.claims_api.report_enabled
        @to = Time.zone.now
        @from = 1.day.ago
        @claims_consumers = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to).pluck(:source).uniq

        ClaimsApi::UnsuccessfulReportMailer.build(
          @from,
          @to,
          consumer_claims_totals: claims_totals,
          unsuccessful_claims_submissions: unsuccessful_claims_submissions,
          poa_totals: poa_totals,
          unsuccessful_poa_submissions: unsuccessful_poa_submissions
        ).deliver_now
      end
    end

    def unsuccessful_claims_submissions
      errored_claims.pluck(:source, :created_at, :id).map do |source, created_at, id|
        { id: id, created_at: created_at, source: source }
      end
    end

    def errored_claims
      ClaimsApi::AutoEstablishedClaim.where(
        created_at: @from..@to,
        status: %w[errored]
      ).order(:source, :status)
    end

    def with_special_issues(source: nil)
      claims = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to)
                                              .where.not(special_issues: nil)

      claims = claims.where(source: source) if source.present?

      claims.order(:source, :status)
    end

    def with_flashes(source: nil)
      claims = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to)
                                              .where('array_length(flashes, 1) >= 1')

      claims = claims.where(source: source) if source.present?

      claims.order(:source, :status)
    end

    def claims_totals
      @claims_consumers.map do |name|
        counts = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to, source: name).group(:status).count
        totals = counts.sum { |_k, v| v }
        percentage_with_flashes = (with_flashes(source: name).count.to_f / totals) * 100
        percentage_with_special_issues = (with_special_issues(source: name).count.to_f / totals) * 100
        if totals.positive?
          {
            name => counts.merge(totals: totals,
                                 percentage_with_flashes: "#{percentage_with_flashes}%",
                                 percentage_with_special_issues: "#{percentage_with_special_issues}%")
                          .deep_symbolize_keys
          }
        end
      end
    end

    def poa_totals
      totals = ClaimsApi::PowerOfAttorney.where(created_at: @from..@to).group(:status).count
      total_submissions = totals.sum { |_k, v| v }
      totals.merge(total: total_submissions).deep_symbolize_keys
    end

    def unsuccessful_poa_submissions
      ClaimsApi::PowerOfAttorney.where(created_at: @from..@to, status: %w[errored]).order(:created_at,
                                                                                          :vbms_error_message)
    end
  end
end
