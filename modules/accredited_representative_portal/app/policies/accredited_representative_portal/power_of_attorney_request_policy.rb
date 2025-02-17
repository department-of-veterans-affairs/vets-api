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
      return false if user.power_of_attorney_holders.empty?

      user.power_of_attorney_holders.any?(&:accepts_digital_power_of_attorney_requests?)
    end

    def user_has_access_to_record?
      user.power_of_attorney_holders.any? do |holder|
        holder.poa_code == record.power_of_attorney_holder_poa_code &&
          holder.accepts_digital_power_of_attorney_requests?
      end
    end

    class Scope < Scope
      def resolve
        return scope.none if user.power_of_attorney_holders.empty?

        allowed_poa_codes = user.power_of_attorney_holders
                                .select(&:accepts_digital_power_of_attorney_requests?)
                                .map(&:poa_code)

        scope.where(power_of_attorney_holder_poa_code: allowed_poa_codes)
      end
    end
  end
end
