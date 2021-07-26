# frozen_string_literal: true

module ClaimsApi
  class BGSToLighthouseClaimsMapperService < ClaimsApi::Service
    attr_accessor :bgs_claims, :lighthouse_claims

    def initialize(bgs_claims:, lighthouse_claims:)
      @bgs_claims        = bgs_claims
      @lighthouse_claims = lighthouse_claims
    end

    def process
      return [] unless claims_exist?

      mapped_claims = map_claims
      mapped_claims = append_remaining_lighthouse_claims(mapped_claims: mapped_claims) if lighthouse_claims.present?
      mapped_claims
    end

    private

    def claims_exist?
      bgs_claims.key?(:bnft_claim_detail) || lighthouse_claims.present?
    end

    def map_claims
      bgs_claims[:bnft_claim_detail].map do |bgs_claim|
        matching_claim = find_bgs_claim_in_lighthouse_collection(claim: bgs_claim)
        if matching_claim
          remove_bgs_claim_from_lighthouse_collection(claim: matching_claim)
          build_matched_claim(matching_claim: matching_claim, bgs_claim: bgs_claim)
        else
          build_unmatched_bgs_claim(bgs_claim: bgs_claim)
        end
      end
    end

    def find_bgs_claim_in_lighthouse_collection(claim:)
      lighthouse_claims.find { |internal_claim| internal_claim.evss_id == claim[:bnft_claim_id] }
    end

    def remove_bgs_claim_from_lighthouse_collection(claim:)
      lighthouse_claims.delete(claim)
    end

    def build_matched_claim(matching_claim:, bgs_claim:)
      # this claim was submitted via Lighthouse, so use the 'id' the user is most likely to know
      { id: matching_claim.id, type: bgs_claim[:bnft_claim_type_nm] }
    end

    def build_unmatched_bgs_claim(bgs_claim:)
      { id: bgs_claim[:bnft_claim_id], type: bgs_claim[:bnft_claim_type_nm] }
    end

    def build_unmatched_lighthouse_claim(lighthouse_claim:)
      { id: lighthouse_claim.id, type: lighthouse_claim.claim_type }
    end

    def append_remaining_lighthouse_claims(mapped_claims:)
      lighthouse_claims.each do |remaining_claim|
        # if claim wasn't matched earlier, then this claim is in a weird state where
        #  it's 'established' in Lighthouse, but unknown to BGS.
        #  shouldn't really ever happen, but if it does, skip it.
        next if remaining_claim.status.casecmp?('established')

        mapped_claims.push(build_unmatched_lighthouse_claim(lighthouse_claim: remaining_claim))
      end

      mapped_claims
    end
  end
end
