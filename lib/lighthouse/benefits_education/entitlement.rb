# frozen_string_literal: true

require 'vets/model'

module BenefitsEducation
  ##
  # Model for the GIBS entitlement
  #
  # @!attribute months
  #   @return [Integer] Number of months in the entitlement
  # @!attribute days
  #   @return [Integer] Number of days in the entitlement
  class Entitlement
    include Vets::Model

    attribute :months, Integer
    attribute :days, Integer
  end
end
