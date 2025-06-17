# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class IntentToFilePolicy < ApplicationPolicy
    include ValidatePowerOfAttorney

    def show?
      authorize_poa
    end

    def create?
      authorize_poa
    end
  end
end
