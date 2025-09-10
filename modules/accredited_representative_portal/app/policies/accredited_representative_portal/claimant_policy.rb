# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class ClaimantPolicy < ApplicationPolicy
    def search?
      @user.power_of_attorney_holders.size.positive?
    end
  end
end
