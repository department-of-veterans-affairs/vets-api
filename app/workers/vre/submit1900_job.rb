# frozen_string_literal: true

module VRE
  class Submit1900Job
    include Sidekiq::Worker

    def perform(claim_id, user_uuid)
      claim = SavedClaim::VeteranReadinessEmploymentClaim.find claim_id
      user = User.find user_uuid
      claim.add_claimant_info(user)
      claim.send_to_vre(user)
    end
  end
end
