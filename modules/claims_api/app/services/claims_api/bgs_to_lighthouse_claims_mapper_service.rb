# frozen_string_literal: true

module ClaimsApi
  class BGSToLighthouseClaimsMapperService < ClaimsApi::Service
    attr_accessor :bgs_claim, :lighthouse_claim

    def initialize(bgs_claim: nil, lighthouse_claim: nil)
      @bgs_claim        = bgs_claim
      @lighthouse_claim = lighthouse_claim
    end

    def process
      return matched_claim if bgs_and_lighthouse_claims_exist?
      return unmatched_bgs_claim if bgs_claim_only?
      return unmatched_lighthouse_claim if lighthouse_claim_only?

      {}
    end

    private

    def bgs_and_lighthouse_claims_exist?
      bgs_claim.present? && lighthouse_claim.present?
    end

    def bgs_claim_only?
      bgs_claim.present? && lighthouse_claim.blank?
    end

    def lighthouse_claim_only?
      bgs_claim.blank? && lighthouse_claim.present?
    end

    def matched_claim
      # this claim was submitted via Lighthouse, so use the 'id' the user is most likely to know
      { id: lighthouse_claim.id, type: bgs_claim[:claim_status_type], status: bgs_claim[:phase_type] }
    end

    def unmatched_bgs_claim
      { id: bgs_claim[:benefit_claim_id], type: bgs_claim[:claim_status_type], status: bgs_claim[:phase_type] }
    end

    def unmatched_lighthouse_claim
      { id: lighthouse_claim.id, type: lighthouse_claim.claim_type, status: lighthouse_claim.status.capitalize }
    end
  end
end
