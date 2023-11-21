# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class LetterInfo
        def parse(letter_info)
          Mobile::V0::LetterInfo.new(
            benefit_information: benefit_information(letter_info[:benefitInformation]),
            military_service: military_service(letter_info[:militaryService])
          )
        end

        private

        def benefit_information(benefits)
          BenefitInformation.new(
            award_effective_date: benefits[:awardEffectiveDate],
            has_chapter35_eligibility: benefits[:hasChapter35Eligibility],
            monthly_award_amount: benefits[:monthlyAwardAmount].to_f,
            service_connected_percentage: benefits[:serviceConnectedPercentage],
            has_death_result_of_disability: benefits[:hasDeathResultOfDisability],
            has_survivors_indemnity_compensation_award: benefits[:hasSurvivorsIndemnityCompensationAward],
            has_survivors_pension_award: benefits[:hasSurvivorsPensionAward],
            has_adapted_housing: benefits[:hasAdaptedHousing],
            has_individual_unemployability_granted: benefits[:hasIndividualUnemployabilityGranted],
            has_non_service_connected_pension: benefits[:hasNonServiceConnectedPension],
            has_service_connected_disabilities: benefits[:hasServiceConnectedDisabilities],
            has_special_monthly_compensation: benefits[:hasSpecialMonthlyCompensation]
          )
        end

        def military_service(military_services)
          military_services.map do |military_service|
            {
              branch: military_service[:branch],
              character_of_service: military_service[:characterOfService],
              entered_date: military_service[:enteredDate],
              released_date: military_service[:releasedDate]
            }
          end
        end
      end
    end
  end
end
