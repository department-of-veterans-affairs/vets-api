# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecisionPolicy < ApplicationPolicy
    def create?
      poa_request_policy = Pundit.policy(@user, PowerOfAttorneyRequest)
      poa_request_policy.create_decision?
    end
  end
end
