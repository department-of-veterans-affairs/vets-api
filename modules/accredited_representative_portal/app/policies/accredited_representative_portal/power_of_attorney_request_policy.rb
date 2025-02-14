# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestPolicy < ApplicationPolicy
    def index?
      user_has_poa_access?
    end

    def show?
      user_has_access_to_record?
    end

    def create_decision?
      user_has_poa_access?
    end

    private

    def user_has_poa_access?
      user_poa_codes.any?
    end

    def user_has_access_to_record?
      user_poa_codes.include?(record.power_of_attorney_holder_poa_code)
    end

    def user_poa_codes
      @user_poa_codes ||= user.power_of_attorney_holders.map(&:poa_code)
    end

    class Scope < Scope
      def resolve
        return scope.none if user_poa_codes.empty?

        scope.for_user(user)
      end

      private

      def user_poa_codes
        @user_poa_codes ||= user.power_of_attorney_holders.map(&:poa_code)
      end
    end
  end
end
