# frozen_string_literal: true

require 'lighthouse/benefits_claims/service'

module AccreditedRepresentativePortal
  class IntentToFilePolicy < ApplicationPolicy
    def show?
      authorize
    end

    def create?
      authorize
    end

    private

    def service
      @service ||= ::BenefitsClaims::Service.new(@record)
    end

    def pilot_user_email_poa_codes
      Settings
        .accredited_representative_portal
        .pilot_user_email_poa_codes.to_h
        .stringify_keys!
    end

    def authorize
      return false unless @user

      poa_code_response = service.get_power_of_attorney
      vet_poa_codes = Set.new(Array(poa_code_response.dig('data', 'attributes', 'code')))
      Set.new(pilot_user_email_poa_codes[@user.email]).intersect? vet_poa_codes
    end
  end
end
