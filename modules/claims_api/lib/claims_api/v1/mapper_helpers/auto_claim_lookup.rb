# frozen_string_literal: true

module ClaimsApi
  module V1
    module AutoClaimLookup
      # Paths used to navigate elements in the auto_claim variable
      AUTO_CLAIM_PATHS = {
        standard_claim: %w[standardClaim],
        # Veteran information paths
        veteran_current_mailing_address: %w[veteran currentMailingAddress],
        veteran_current_va_employee: %w[veteran currentlyVAEmployee],
        veteran_change_of_address: %w[veteran changeOfAddress],
        veteran_homelessness: %w[veteran homelessness],
        veteran_homelessness_point_of_contact: %w[veteran homelessness pointOfContact],
        veteran_homelessness_currently_homeless: %w[veteran homelessness currentlyHomeless],
        veteran_homelessness_risk: %w[veteran homelessness homelessnessRisk],
        # Treatment and disability paths
        treatments: %w[treatments],
        disabilities: %w[disabilities],
        # Service information paths
        service_periods: %w[serviceInformation servicePeriods],
        reserves_service: %w[serviceInformation reservesNationalGuardService],
        reserves_unit_name: %w[serviceInformation reservesNationalGuardService unitName],
        reserves_unit_phone: %w[serviceInformation reservesNationalGuardService unitPhone],
        reserves_obligation_from: %w[serviceInformation reservesNationalGuardService obligationTermOfServiceFromDate],
        reserves_obligation_to: %w[serviceInformation reservesNationalGuardService obligationTermOfServiceToDate],
        reserves_title_10_activation: %w[serviceInformation reservesNationalGuardService title10Activation],
        reserves_alternate_names: %w[serviceInformation alternateNames],
        service_confinements: %w[serviceInformation confinements]
      }.freeze

      def lookup_in_auto_claim(path_key)
        @auto_claim.dig(*AUTO_CLAIM_PATHS[path_key])
      end
    end
  end
end
