# frozen_string_literal: true

require 'sidekiq'

module ClaimsApi
  class ReportUnsuccessfulSubmissions
    include Sidekiq::Worker

    def perform
      if Settings.claims_api.report_enabled
        @to = Time.zone.now
        @from = @to.monday? ? 7.days.ago : 1.day.ago
        @claims_consumers = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to).pluck(:source).uniq

        ClaimsApi::UnsuccessfulReportMailer.build(
          @from,
          @to,
          consumer_claims_totals: claims_totals,
          pending_claims_submissions: pending_claims,
          unsuccessful_claims_submissions: unsuccessful_claims_submissions,
          grouped_claims_errors: claims_errors_hash[:uniq_errors],
          grouped_claims_warnings: claims_errors_hash[:uniq_warnings],
          flash_statistics: flash_statistics,
          special_issues_statistics: si_statistics,
          poa_totals: poa_totals,
          unsuccessful_poa_submissions: unsuccessful_poa_submissions
        ).deliver_now
      end
    end

    def unsuccessful_claims_submissions
      errored_claims.pluck(:source, :status, :id).map do |source, status, id|
        { id: id, status: status, source: source }
      end
    end

    def errored_claims
      ClaimsApi::AutoEstablishedClaim.where(
        created_at: @from..@to,
        status: %w[errored]
      ).order(:source, :status)
    end

    def claims_errors_hash
      return @claims_errors_hash if @claims_errors_hash

      errors_array = errored_claims.flat_map do |error|
        if error.evss_response.present?
          uuid_regex = /[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}/
          error.evss_response = error.evss_response.to_s.gsub(uuid_regex, '%<uuid>')
          error.evss_response = error.evss_response.to_s.gsub(/\d{5,}/, '%<number>')
          error.evss_response = error.evss_response.to_s.gsub(/\[\d\]/, '[%<number>]')
          begin
            error.evss_response = JSON.parse(error.evss_response.gsub('=>', ':'))
          rescue
            # message not guaranteed to be in hash format
            []
          end
        end
      end

      @claims_errors_hash = { uniq_errors: count_uniqs(errors_array.select do |n|
                                                         %w[ERROR FATAL].include?(n['severity']) if n
                                                       end),
                              uniq_warnings: count_uniqs(errors_array.select { |n| n['severity'] == 'WARN' if n }) }
    end

    def count_uniqs(array)
      counted_array = array.each_with_object(Hash.new(0)) { |word, counts| counts[word] += 1 }
      sorted_array = counted_array.sort_by { |_k, v| v }.reverse
      sorted_array.map do |code, counts|
        { code: code, count: counts, percentage: '%' }
      end
    end

    def pending_claims
      ClaimsApi::AutoEstablishedClaim.where(
        created_at: @from..@to,
        status: 'pending'
      ).order(:source, :status).pluck(:source, :status, :id).map do |source, status, id|
        { id: id, status: status, source: source }
      end
    end

    def si_statistics
      submissions_with_special_issues = with_special_issues
      return [] if submissions_with_special_issues.blank?

      unique_special_issues = submissions_with_special_issues.pluck(:special_issues).sum.uniq
      aggregations = unique_special_issues.map { |special_issue| { code: special_issue, count: 0 } }
      submissions_with_special_issues.each do |submission|
        submission.special_issues.each do |special_issue|
          aggregation = aggregations.detect { |agg| agg[:code] == special_issue }
          aggregation[:count] = aggregation[:count] + 1
        end
      end

      totals = submissions_with_special_issues.count
      aggregations.each do |aggregation|
        aggregation[:percentage] = "#{(aggregation[:count].to_f / totals) * 100}%"
      end

      aggregations
    end

    def with_special_issues(source: nil)
      claims = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to)
                                              .where.not(special_issues: nil)

      claims = claims.where(source: source) if source.present?

      claims.order(:source, :status)
    end

    def flash_statistics
      submissions_with_flashes = with_flashes
      return [] if submissions_with_flashes.blank?

      unique_flashes = submissions_with_flashes.pluck(:flashes).sum.uniq
      aggregations = unique_flashes.map { |flash| { code: flash, count: 0 } }
      submissions_with_flashes.each do |submission|
        submission.flashes.each do |flash|
          aggregation = aggregations.detect { |agg| agg[:code] == flash }
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

    def claims_totals
      @claims_consumers.map do |name|
        counts = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to, source: name).group(:status).count
        totals = counts.sum { |_k, v| v }
        error_rate = counts['errored'] ? (100.0 / totals * counts['errored']).round : 0
        percentage_with_flashes = (with_flashes(source: name).count.to_f / totals) * 100
        percentage_with_special_issues = (with_special_issues(source: name).count.to_f / totals) * 100
        if totals.positive?
          {
            name => counts.merge(totals: totals,
                                 error_rate: "#{error_rate}%",
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
      totals.merge(total: total_submissions)
    end

    def unsuccessful_poa_submissions
      ClaimsApi::PowerOfAttorney.where(created_at: @from..@to, status: %w[errored]).order(:created_at,
                                                                                          :vbms_error_message)
    end
  end
end
