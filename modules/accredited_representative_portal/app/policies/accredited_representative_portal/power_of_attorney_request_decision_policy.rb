# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecisionPolicy < ApplicationPolicy
    def create?
      Pundit
        .policy(@user, PowerOfAttorneyRequest)
        .create_decision?
    end
  end
end
