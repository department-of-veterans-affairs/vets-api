# frozen_string_literal: true

module EVSS
  module Letters
    ##
    # Model for a dependent's benefit information
    #
    # @!attribute has_survivors_pension_award
    #   @return [Bool] Returns true if the user has a survivor's pension award
    # @!attribute has_survivors_indemnity_compensation_award
    #   @return [Bool] Returns true if the user has a survivor's indemnity compensation award
    # @!attribute has_death_result_of_disability
    #   @return [Bool] Returns true of the veteran died as a result of their disability
    #
    class BenefitInformationDependent < BenefitInformation
      attribute :has_survivors_pension_award, Bool
      attribute :has_survivors_indemnity_compensation_award, Bool
      attribute :has_death_result_of_disability, Bool
    end
  end
end
