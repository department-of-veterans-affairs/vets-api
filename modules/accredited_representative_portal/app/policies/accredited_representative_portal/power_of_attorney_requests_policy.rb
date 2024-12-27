# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestsPolicy < ApplicationPolicy
    def index?
      authorize
    end

    def show?
      authorize
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        PowerOfAttorneyRequest.includes(
          :power_of_attorney_form,
          :power_of_attorney_holder,
          :accredited_individual,
          resolution: :resolving
        )
      end
    end

    private

    def pilot_user_email_poa_codes
      Settings
        .accredited_representative_portal
        .pilot_user_email_poa_codes.to_h
        .stringify_keys!
    end

    def authorize
      return false unless @user

      pilot_user_poa_codes = Set.new(Array.wrap(pilot_user_email_poa_codes[@user&.email]))
      poa_requests_poa_codes = Set.new(Array.wrap(@record), &:poa_code)

      pilot_user_poa_codes >= poa_requests_poa_codes
    end
  end
end
