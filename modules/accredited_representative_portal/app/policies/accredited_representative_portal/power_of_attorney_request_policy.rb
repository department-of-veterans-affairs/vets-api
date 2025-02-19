# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestPolicy < ApplicationPolicy
    def index?
      authorize
    end

    def show?
      authorize
    end

    def create_decision?
      authorize
    end

    private

    def authorize
      user.activated_power_of_attorney_holders.any?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.for_user(user)
      end
    end
  end
end
