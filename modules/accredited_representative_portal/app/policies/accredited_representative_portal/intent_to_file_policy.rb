# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class IntentToFilePolicy < ApplicationPolicy
    def show?
      claimant_representative.present?
    end

    def create?
      claimant_representative.present?
    end

    private

    def claimant_representative
      ClaimantRepresentative.find(
        claimant_icn: @record,
        power_of_attorney_holder_memberships:
          @user.power_of_attorney_holder_memberships
      )
    end
  end
end
