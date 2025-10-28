# frozen_string_literal: true

module ClaimsApi
  module V1
    module AutoClaimLookup
      # Paths used to navigate elements in the auto_claim variable, these match what is in the 526.json schema
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
        # SECTION 5: Treatment and disability paths
        treatments: %w[treatments],
        disabilities: %w[disabilities],
        # SECTION 6: Service information paths
        service_periods: %w[serviceInformation servicePeriods],
        reserves_service: %w[serviceInformation reservesNationalGuardService],
        reserves_unit_name: %w[serviceInformation reservesNationalGuardService unitName],
        reserves_unit_phone: %w[serviceInformation reservesNationalGuardService unitPhone],
        reserves_obligation_from: %w[serviceInformation reservesNationalGuardService obligationTermOfServiceFromDate],
        reserves_obligation_to: %w[serviceInformation reservesNationalGuardService obligationTermOfServiceToDate],
        reserves_title_10_activation: %w[serviceInformation reservesNationalGuardService title10Activation],
        reserves_alternate_names: %w[serviceInformation alternateNames],
        service_confinements: %w[serviceInformation confinements],
        # SECTION 7: Service Pay
        service_pay: %w[servicePay],
        service_pay_military_retired_pay: %w[servicePay militaryRetiredPay],
        service_pay_retain_training_pay: %w[servicePay waiveVABenefitsToRetainTrainingPay],
        service_pay_retain_retired_pay: %w[servicePay waiveVABenefitsToRetainRetiredPay],
        service_pay_receiving_retired_pay: %w[servicePay militaryRetiredPay receiving],
        service_pay_future_military_pay: %w[servicePay militaryRetiredPay willReceiveInFuture],
        service_pay_future_pay_explanation: %w[servicePay militaryRetiredPay futurePayExplanation],
        military_retired_pay_payment: %w[servicePay militaryRetiredPay payment],
        military_retired_pay_service_branch: %w[servicePay militaryRetiredPay payment serviceBranch],
        military_retired_pay_amount: %w[servicePay militaryRetiredPay payment amount],
        service_pay_separation_pay: %w[servicePay separationPay],
        service_pay_separation_or_severance_pay_received: %w[servicePay separationPay received],
        separation_pay_received_date: %w[servicePay separationPay receivedDate],
        separation_pay_branch_of_service: %w[servicePay separationPay payment serviceBranch],
        separation_pay_amount: %w[servicePay separationPay payment amount],
        # SECTION 8: Direct Deposit
        direct_deposit: %w[directDeposit],
        direct_deposit_account_type: %w[directDeposit accountType],
        direct_deposit_account_number: %w[directDeposit accountNumber],
        direct_deposit_routing_number: %w[directDeposit routingNumber],
        direct_deposit_bank_name: %w[directDeposit bankName],
        # SECTION 9: Claim Certification and Signature
        claim_date: %w[claimDate]
      }.freeze

      def lookup_in_auto_claim(path_key)
        @auto_claim.dig(*AUTO_CLAIM_PATHS[path_key])
      end
    end
  end
end
