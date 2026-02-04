# frozen_string_literal: true

require_relative 'service'

module BGS
  class VnpBenefitClaim
    def initialize(proc_id:, veteran:, user:)
      @user = user
      @veteran = veteran
      @proc_id = proc_id
    end

    def create
      vnp_benefit_claim = bgs_service.vnp_create_benefit_claim(
        bgs_vnp_benefit_claim.create_params_for_686c
      )

      bgs_vnp_benefit_claim.vnp_benefit_claim_response(vnp_benefit_claim)
    end

    def update(benefit_claim, vnp_benefit_claim)
      bgs_service.vnp_benefit_claim_update(
        bgs_vnp_benefit_claim.update_params_for_686c(vnp_benefit_claim, benefit_claim)
      )
    end

    private

    def bgs_vnp_benefit_claim
      BGSDependents::VnpBenefitClaim.new(
        @proc_id,
        @veteran
      )
    end

    def bgs_service
      BGS::Service.new(@user)
    end
  end
end
