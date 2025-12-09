# frozen_string_literal: true

require 'vets/model'

module EVSS
  module Letters
    ##
    # Model for benefit information
    #
    # @!attribute monthly_award_amount
    #   @return [Float] Dollar amount that the user receives monthly
    # @!attribute service_connected_percentage
    #   @return [Integer] The VA's rating of the veteran's service-connected disability or disabilities
    # @!attribute award_effective_date
    #   @return [DateTime] The date and time that the user's benefit award goes into effect
    # @!attribute has_chapter35_eligiblity
    #   @return [Boolean] Returns true if the user is Chapter 35-eligible
    #
    class BenefitInformation
      include Vets::Model

      attribute :monthly_award_amount, Float
      attribute :service_connected_percentage, Integer
      attribute :award_effective_date, DateTime
      attribute :has_chapter35_eligibility, Bool
    end
  end
end
