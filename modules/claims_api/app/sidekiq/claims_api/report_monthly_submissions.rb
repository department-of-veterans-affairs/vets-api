# frozen_string_literal: true

module ClaimsApi
  class ReportMonthlySubmissions < ClaimsApi::ReportingBase
    def perform
      return unless Settings.claims_api.report_enabled

      @from = 1.month.ago
      @to = Time.zone.now
      @claims_consumers = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to).pluck(:cid).uniq
      @poa_consumers = ClaimsApi::PowerOfAttorney.where(created_at: @from..@to).pluck(:cid).uniq
      @itf_consumers = ClaimsApi::IntentToFile.where(created_at: @from..@to).pluck(:cid).uniq
      @ews_consumers = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to).pluck(:cid).uniq

      ClaimsApi::SubmissionReportMailer.build(
        @from,
        @to,
        consumer_claims_totals: monthly_claims_totals,
        poa_totals: monthly_poa_totals,
        itf_totals: monthly_itf_totals,
        ews_totals: monthly_ews_totals
      ).deliver_now
    end

    private

    def get_monthly_summary_by_consumer_by_status(monthly_summary_by_cid_by_status, monthly_pact_claims_by_cid = nil)
      totals_row = Hash.new(0)

      monthly_summary_by_consumer_by_status = monthly_summary_by_cid_by_status.map do |cid, column_counts|
        column_counts[:totals] = column_counts.values.sum
        column_counts[:pact_count] = monthly_pact_claims_by_cid[cid] if monthly_pact_claims_by_cid

        column_counts.symbolize_keys!

        column_counts.each do |column, count|
          totals_row[column] += count
        end

        { ClaimsApi::CidMapper.new(cid:).name => column_counts }
      end

      monthly_summary_by_consumer_by_status.tap do |rows|
        rows << { 'Totals' => totals_row } unless totals_row.empty?
      end
    end

    def group_by_cid_by_status(consumers)
      consumers.group_by(&:cid).transform_values do |submissions|
        submissions.group_by(&:status).transform_values(&:count)
      end
    end

    def monthly_claims_totals
      monthly_claims_consumers = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to)
      monthly_pact_claims = ClaimsApi::ClaimSubmission.where(created_at: @from..@to,
                                                             claim_id: monthly_claims_consumers.pluck(:id))
      monthly_claims_by_cid_by_status = group_by_cid_by_status(monthly_claims_consumers)

      monthly_pact_claims_by_cid = monthly_pact_claims.each_with_object(Hash.new(0)) do |pact_claim, hash|
        cid = monthly_claims_consumers.find { |claim| claim.id == pact_claim.claim_id }&.cid
        hash[cid] += 1 if cid
      end

      get_monthly_summary_by_consumer_by_status(monthly_claims_by_cid_by_status, monthly_pact_claims_by_cid)
    end

    def monthly_poa_totals
      monthly_poa_consumers = ClaimsApi::PowerOfAttorney.where(created_at: @from..@to)
      monthly_poa_by_cid_by_status = group_by_cid_by_status(monthly_poa_consumers)

      get_monthly_summary_by_consumer_by_status(monthly_poa_by_cid_by_status)
    end

    def monthly_itf_totals
      monthly_itf_consumers = ClaimsApi::IntentToFile.where(created_at: @from..@to)
      monthly_itf_by_cid_by_status = group_by_cid_by_status(monthly_itf_consumers)

      get_monthly_summary_by_consumer_by_status(monthly_itf_by_cid_by_status)
    end

    def monthly_ews_totals
      monthly_ews_consumers = ClaimsApi::EvidenceWaiverSubmission.where(created_at: @from..@to)
      monthly_ews_by_cid_by_status = group_by_cid_by_status(monthly_ews_consumers)

      get_monthly_summary_by_consumer_by_status(monthly_ews_by_cid_by_status)
    end
  end
end
