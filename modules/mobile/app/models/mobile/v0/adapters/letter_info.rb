# frozen_string_literal: true

module Mobile
  module V0
    module Adapters
      class LetterInfo
        def parse(letter_info)
          Mobile::V0::LetterInfo.new(
            benefit_information: benefit_information(letter_info[:benefit_information]),
            military_service: military_service(letter_info[:military_services])
          )
        end

        private

        def benefit_information(benefits)
          BenefitInformation.new(
            award_effective_date: benefits[:award_effective_date_time],
            has_chapter_35_eligibility: benefits[:chapter35_eligibility],
            monthly_award_amount: benefits.dig(:monthly_award_amount, :value).to_f,
            service_connected_percentage: benefits[:service_connected_percentage],
            has_death_result_of_disability: benefits[:has_death_result_of_disability],
            has_survivors_indemnity_compensation_award: benefits[:has_survivors_indemnity_compensation_award],
            has_survivors_pension_award: benefits[:has_survivors_pension_award],
            has_adapted_housing: benefits[:adapted_housing],
            has_individual_unemployability_granted: benefits[:individual_unemployability_granted],
            has_non_service_connected_pension: benefits[:non_service_connected_pension],
            has_service_connected_disabilities: benefits[:service_connected_disabilities],
            has_special_monthly_compensation: benefits[:special_monthly_compensation]
          )
        end

        def military_service(military_services)
          military_services.map do |military_service|
            {
              branch: military_service[:branch],
              characterOfService: military_service[:character_of_service],
              enteredDate: military_service[:entered_date_time],
              releasedDate: military_service[:released_date_time]
            }
          end
        end
      end
    end
  end
end
