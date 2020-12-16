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

        ClaimsApi::UnsuccessfulReportMailer.build(@from, @to, consumer_totals: totals,
                                                              pending_submissions: pending,
                                                              unsuccessful_submissions: errored_grouped,
                                                              flash_statistics: flash_statistics).deliver_now
      end
    end

    def errored
      ClaimsApi::AutoEstablishedClaim.where(
        created_at: @from..@to,
        status: %w[errored]
      ).order(:source, :status)
    end

    def errored_grouped
      generized_errors = errored.map do |error|
        if error.evss_response.present?
          uuid_regex = /[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}/
          error.evss_response = error.evss_response.to_s.gsub(uuid_regex, '%<uuid>')
          error.evss_response = error.evss_response.to_s.gsub(/\d{5,}/, '%<number>')
          begin
            error.evss_response = JSON.parse(error.evss_response.gsub('=>', ':'))
          rescue
            # message not guaranteed to be in hash format
          end
        end

        error
      end

      generized_errors.uniq { |error| [error.source, error.status, error.evss_response] }
    end

    def pending
      ClaimsApi::AutoEstablishedClaim.where(
        created_at: @from..@to,
        status: 'pending'
      ).order(:source, :status)
    end

    def flash_statistics
      submissions_with_flashes = with_flashes
      return [] if submissions_with_flashes.blank?

      unique_flashes = submissions_with_flashes.pluck(:flashes).sum.uniq
      aggregations = unique_flashes.map { |flash| { flash: flash, count: 0 } }
      submissions_with_flashes.each do |submission|
        submission.flashes.each do |flash|
          aggregation = aggregations.detect { |agg| agg[:flash] == flash }
          aggregation[:count] = aggregation[:count] + 1
        end
      end

      totals = submissions_with_flashes.count
      aggregations.each do |aggregation|
        aggregation[:percentage] = "#{(aggregation[:count].to_f / totals) * 100}%"
      end

      aggregations
    end

    def with_flashes(source: nil)
      claims = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to)
                                              .where('array_length(flashes, 1) >= 1')

      claims = claims.where(source: source) if source.present?

      claims.order(:source, :status)
    end

    def totals
      @consumers.map do |name|
        counts = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to, source: name).group(:status).count
        totals = counts.sum { |_k, v| v }
        error_rate = counts['errored'] ? (100.0 / totals * counts['errored']).round : 0
        percentage_with_flashes = (with_flashes(source: name).count.to_f / totals) * 100
        if totals.positive?
          {
            name => counts.merge(totals: totals,
                                 error_rate: "#{error_rate}%",
                                 percentage_with_flashes: "#{percentage_with_flashes}%")
          }
        end
      end
    end
  end
end
