# frozen_string_literal: true

module ClaimsApi
  class BGSToLighthouseClaimsMapperService < ClaimsApi::Service
    attr_accessor :bgs_claims, :lighthouse_claims

    def initialize(bgs_claims:, lighthouse_claims:)
      @bgs_claims        = bgs_claims
      @lighthouse_claims = lighthouse_claims
    end

    def process
      return [] unless bgs_claims.key?(:bnft_claim_detail) || lighthouse_claims.present?

      mapped_claims = bgs_claims[:bnft_claim_detail].map do |external_claim|
        match = lighthouse_claims.find { |internal_claim| internal_claim.evss_id == external_claim[:bnft_claim_id] }

        if match
          lighthouse_claims.delete(match)
          { id: match.id, type: external_claim[:bnft_claim_type_nm] }
        else
          { id: external_claim[:bnft_claim_id], type: external_claim[:bnft_claim_type_nm] }
        end
      end

      if lighthouse_claims.present?
        lighthouse_claims.each do |remaining_claim|
          mapped_claims.push({ id: remaining_claim.id, type: remaining_claim.claim_type })
        end
      end

      mapped_claims
    end
  end
end
