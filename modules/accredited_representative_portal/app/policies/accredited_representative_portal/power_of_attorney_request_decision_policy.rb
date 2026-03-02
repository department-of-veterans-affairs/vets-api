# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestDecisionPolicy < ApplicationPolicy
    def create?
      Pundit.policy(@user, @record).create_decision?
    end
  end
end
