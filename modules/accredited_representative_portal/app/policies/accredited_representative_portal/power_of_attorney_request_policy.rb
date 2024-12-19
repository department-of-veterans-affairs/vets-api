# frozen_string_literal: true

module AccreditedRepresentativePortal
  class PowerOfAttorneyRequestPolicy < ApplicationPolicy
    def index?
      authorize
    end

    def show?
      authorize
    end

    class Scope < ApplicationPolicy::Scope
      def resolve
        ::AccreditedRepresentativePortal::POA_REQUEST_LIST_MOCK_DATA
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

      pilot_user_poa_codes = Set.new(pilot_user_email_poa_codes[@user&.email])
      poa_requests_poa_codes = Set.new(Array.wrap(@record)) { |r| r.dig(:attributes, :powerOfAttorneyCode) }

      pilot_user_poa_codes >= poa_requests_poa_codes
    end
  end
end
