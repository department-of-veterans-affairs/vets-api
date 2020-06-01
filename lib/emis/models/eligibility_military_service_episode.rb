# frozen_string_literal: true

require_relative 'combat_pay'
require_relative 'eligibility_deployment'

module EMIS
  module Models
    # EMIS Eligibility Military Service Episode data
    #
    # @!attribute begin_date
    #   @return [Date] date when a sponsor's personnel category and organizational
    #     affiliation began.
    # @!attribute end_date
    #   @return [Date] date when the personnel segment terminated.
    # @!attribute branch_of_service_code
    #   (see EMIS::Models::MilitaryServiceEpisode#branch_of_service_code)
    # @!attribute discharge_character_of_service_code
    #   (see EMIS::Models::MilitaryServiceEpisode#discharge_character_of_service_code)
    # @!attribute honorable_discharge_for_va_purpose_code
    #   (see EMIS::Models::MilitaryServiceEpisode#honorable_discharge_for_va_purpose_code)
    # @!attribute narrative_reason_for_separation_code
    #   (see EMIS::Models::MilitaryServiceEpisode#narrative_reason_for_separation_code)
    # @!attribute deployments
    #   @return [Array<EMIS::Models::EligibilityDeployment>] associated eligibility deployments
    # @!attribute combat_pay
    #   @return [Array<EMIS::Models::CombatPay>] associated combat pay data
    class EligibilityMilitaryServiceEpisode
      include Virtus.model

      attribute :begin_date, Date
      attribute :end_date, Date
      attribute :branch_of_service_code, String
      attribute :discharge_character_of_service_code, String
      attribute :honorable_discharge_for_va_purpose_code, String
      attribute :narrative_reason_for_separation_code, String
      attribute :deployments, Array[EligibilityDeployment]
      attribute :combat_pay, Array[EMIS::Models::CombatPay]
    end
  end
end
