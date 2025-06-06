# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SavedClaimClaimantRepresentativePolicy < ApplicationPolicy
    def index?
      authorize
    end

    private

    def authorize
      @user.user_account.active_power_of_attorney_holders.size.positive?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        @scope.for_power_of_attorney_holders(
          @user.user_account.active_power_of_attorney_holders
        )
      end
    end
  end
end
