# frozen_string_literal: true

require 'common/models/base'

module BenefitsEducation
  ##
  # Model for the GIBS entitlement
  #
  # @!attribute months
  #   @return [Integer] Number of months in the entitlement
  # @!attribute days
  #   @return [Integer] Number of days in the entitlement
  class Entitlement < Common::Base
    attribute :months, Integer
    attribute :days, Integer
  end
end
