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
      @user.power_of_attorney_holders.any?(
        &:accepts_digital_power_of_attorney_requests?
      )
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        @scope.unredacted.for_power_of_attorney_holders(
          @user.power_of_attorney_holders.select(
            &:accepts_digital_power_of_attorney_requests?
          )
        )
      end
    end
  end
end
