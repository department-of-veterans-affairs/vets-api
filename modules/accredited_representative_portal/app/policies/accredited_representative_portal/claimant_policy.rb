# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class ClaimantPolicy < ApplicationPolicy
    def search?
      @user.representative?
    end

    def show?
      return false unless @user.representative?

      claimant_representative.present?
    end

    private

    def claimant_representative
      ClaimantRepresentative.find(
        claimant_icn: @record,
        power_of_attorney_holder_memberships:
          @user.power_of_attorney_holder_memberships
      )
    rescue ClaimantRepresentative::Finder::Error
      nil
    end
  end
end
