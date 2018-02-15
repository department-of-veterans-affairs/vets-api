# frozen_string_literal: true

class SubmitSavedClaimJob
  include Sidekiq::Worker

  def perform(saved_claim_id)
    claim = SavedClaim.find(saved_claim_id)
  end
end
