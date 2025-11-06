# frozen_string_literal: true

module AccreditedRepresentativePortal
  class DisabilityCompensationFormPolicy < ApplicationPolicy
    def submit_all_claim?
      # Same authorization logic as RepresentativeFormUploadPolicy#submit?
      # The record should be a ClaimantRepresentative that represents the relationship
      # between the representative and the claimant/veteran
      @record.present?
    end
  end
end
