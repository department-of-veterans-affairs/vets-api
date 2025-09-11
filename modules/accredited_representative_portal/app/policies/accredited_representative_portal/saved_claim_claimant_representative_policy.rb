# frozen_string_literal: true

module AccreditedRepresentativePortal
  class SavedClaimClaimantRepresentativePolicy < ApplicationPolicy
    def index?
      authorize
    end

    private

    def authorize
      @user.power_of_attorney_holders.size.positive?
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        @scope.for_power_of_attorney_holders(
          @user.power_of_attorney_holders
        ).where(
          accredited_individual_registration_number:
            @user.registration_numbers
        )
      end
    end
  end
end
