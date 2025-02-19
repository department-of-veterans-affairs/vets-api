# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestPolicy < ApplicationPolicy
    def index?
      authorize
    end

    def show?
      authorize && allowed_poa_codes.include?(record.power_of_attorney_holder_poa_code)
    end

    def create_decision?
      authorize
    end

    private

    def authorize
      user.power_of_attorney_holders.any?(&:accepts_digital_power_of_attorney_requests?)
    end

    def allowed_poa_codes
      @allowed_poa_codes ||= user.power_of_attorney_holders
                                 .select(&:accepts_digital_power_of_attorney_requests?)
                                 .map(&:poa_code)
    end

    class Scope < Scope
      def resolve
        return scope.none unless user.power_of_attorney_holders.any?(&:accepts_digital_power_of_attorney_requests?)

        scope.where(power_of_attorney_holder_poa_code: allowed_poa_codes)
      end

      private

      def allowed_poa_codes
        user.power_of_attorney_holders
            .select(&:accepts_digital_power_of_attorney_requests?)
            .map(&:poa_code)
      end
    end
  end
end
