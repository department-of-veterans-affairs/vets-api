# frozen_string_literal: true

module BGS
  class BenefitClaim < Base
    def initialize(vnp_benefit_claim:, veteran:, user:)
      @vnp_benefit_claim = vnp_benefit_claim
      @veteran = veteran

      super(user)
    end

    def create
      benefit_claim = insert_benefit_claim(@vnp_benefit_claim, @veteran)

      {
        benefit_claim_id: benefit_claim.dig(:benefit_claim_record, :benefit_claim_id),
        claim_type_code: benefit_claim.dig(:benefit_claim_record, :claim_type_code),
        participant_claimant_id: benefit_claim.dig(:benefit_claim_record, :participant_claimant_id),
        program_type_code: benefit_claim.dig(:benefit_claim_record, :program_type_code),
        service_type_code: benefit_claim.dig(:benefit_claim_record, :service_type_code),
        status_type_code: benefit_claim.dig(:benefit_claim_record, :status_type_code),
      }
    end
  end
end
