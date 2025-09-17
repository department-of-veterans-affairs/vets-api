# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class ClaimantPolicy < ApplicationPolicy
    def search?
      @user.representative?
    end
  end
end
