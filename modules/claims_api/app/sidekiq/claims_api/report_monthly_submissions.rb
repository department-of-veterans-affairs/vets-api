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
        poa_totals:,
        itf_totals:,
        ews_totals:
      ).deliver_now
    end

    private

    def monthly_claims_totals
      monthly_claims_consumers = ClaimsApi::AutoEstablishedClaim.where(created_at: @from..@to)
      monthly_pact_claims = ClaimsApi::ClaimSubmission.where(created_at: @from..@to,
                                                             claim_id: monthly_claims_consumers.pluck(:id))

      monthly_claims_by_cid_by_status = monthly_claims_consumers.group_by(&:cid).transform_values do |claims|
        claims.group_by(&:status).transform_values(&:count)
      end

      monthly_pact_claims_by_cid = monthly_pact_claims.each_with_object(Hash.new(0)) do |pact_claim, hash|
        cid = monthly_claims_consumers.find { |claim| claim.id == pact_claim.claim_id }&.cid
        hash[cid] += 1 if cid
      end

      monthly_claims_by_cid_by_status.map do |cid, status_counts|
        status_counts[:totals] = status_counts.values.sum
        status_counts[:pact_count] = monthly_pact_claims_by_cid[cid]
        {
          ClaimsApi::CidMapper.new(cid:).name => status_counts.deep_symbolize_keys
        }
      end
    end
  end
end
