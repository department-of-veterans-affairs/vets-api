# frozen_string_literal: true

module Swagger
  module Schemas
    class LetterBeneficiary
      include Swagger::Blocks

      swagger_schema :LetterBeneficiary do
        key :required, [:data]
        property :data, type: :object do
          key :required, [:attributes]
          property :attributes, type: :object do
            key :required, %i[benefit_information military_service]
            property :benefit_information, type: :object do
              property :has_non_service_connected_pension, type: :boolean, example: true
              property :has_service_connected_disabilities, type: :boolean, example: true
              property :has_survivors_indemnity_compensation_award, type: :boolean, example: true
              property :has_survivors_pension_award, type: :boolean, example: true
              property :monthly_award_amount, type: :number, example: 123.5
              property :service_connected_percentage, type: :integer, example: 2
              property :award_effective_date, type: :string, example: true
              property :has_adapted_housing, type: %i[boolean null], example: true
              property :has_chapter35_eligibility, type: %i[boolean null], example: true
              property :has_death_result_of_disability, type: %i[boolean null], example: true
              property :has_individual_unemployability_granted, type: %i[boolean null], example: true
              property :has_special_monthly_compensation, type: %i[boolean null], example: true
            end
            property :military_service do
              items do
                property :branch, type: :string, example: 'ARMY'
                property :character_of_service, type: :string, enum:
                  %w[
                    HONORABLE
                    OTHER_THAN_HONORABLE
                    UNDER_HONORABLE_CONDITIONS
                    GENERAL
                    UNCHARACTERIZED
                    UNCHARACTERIZED_ENTRY_LEVEL
                    DISHONORABLE
                  ], example: 'HONORABLE'
                property :entered_date, type: :string, example: '1973-01-01T05:00:00.000+00:00'
                property :released_date, type: :string, example: '1977-10-01T04:00:00.000+00:00'
              end
            end
          end
          property :id, type: :string, example: nil
          property :type, type: :string, example: 'evss_letters_letter_beneficiary_response'
        end
      end
    end
  end
end
