# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module Letters
    ##
    # Model for a veteran's benefit information
    #
    # @!attribute has_non_service_connected_pension
    #   @return [Boolean] Returns true if the user has a pension unconnected to their service
    # @!attribute has_service_connected_disabilities
    #   @return [Boolean] Returns true if the user has a disability connected to their service
    # @!attribute has_adapted_housing
    #   @return [Boolean] Returns true if the user has adapted housing
    # @!attribute has_individual_unemployability_granted
    #   @return [Boolean] Returns true if the user has been granted individual unemployability
    # @!attribute has_special_monthly_compensation
    #   @return [Boolean] Returns true if the user has special monthly compensation
    #
    class BenefitInformationVeteran < BenefitInformation
      attribute :has_non_service_connected_pension, Boolean
      attribute :has_service_connected_disabilities, Boolean
      attribute :has_adapted_housing, Boolean
      attribute :has_individual_unemployability_granted, Boolean
      attribute :has_special_monthly_compensation, Boolean
    end
  end
end
