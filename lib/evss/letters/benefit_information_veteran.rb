# frozen_string_literal: true

module EVSS
  module Letters
    ##
    # Model for a veteran's benefit information
    #
    # @!attribute has_non_service_connected_pension
    #   @return [Bool] Returns true if the user has a pension unconnected to their service
    # @!attribute has_service_connected_disabilities
    #   @return [Bool] Returns true if the user has a disability connected to their service
    # @!attribute has_adapted_housing
    #   @return [Bool] Returns true if the user has adapted housing
    # @!attribute has_individual_unemployability_granted
    #   @return [Bool] Returns true if the user has been granted individual unemployability
    # @!attribute has_special_monthly_compensation
    #   @return [Bool] Returns true if the user has special monthly compensation
    #
    class BenefitInformationVeteran < BenefitInformation
      attribute :has_non_service_connected_pension, Bool
      attribute :has_service_connected_disabilities, Bool
      attribute :has_adapted_housing, Bool
      attribute :has_individual_unemployability_granted, Bool
      attribute :has_special_monthly_compensation, Bool
    end
  end
end
