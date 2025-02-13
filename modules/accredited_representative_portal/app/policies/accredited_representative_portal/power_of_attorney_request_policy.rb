# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestPolicy < ApplicationPolicy
    def show?
      authorize
    end

    def index?
      authorize
    end

    def create_decision?
      authorize
    end

    private

    def authorize
      ##
      # When the user is associated with any POA codes, then scenarios in which
      # they are trying to perform an operation against a POA request to which
      # they are not associated should be thought of as having an empty result
      # (`404`).
      #
      # However, when the user is not associated with any POA codes, then they
      # should be informed that they are not authorized to perform operations
      # against these resources.
      #
      raise Pundit::NotAuthorizedError if user_poa_codes.empty?

      user_poa_codes.include?(@record.power_of_attorney_holder_poa_code)
    end

    def user_poa_codes
      @user_poa_codes ||= @user.power_of_attorney_holders.map(&:poa_code)
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        @scope.for_user(@user)
      end
    end
  end
end
