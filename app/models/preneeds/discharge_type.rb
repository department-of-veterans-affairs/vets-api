# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Models a discharge types from the EOAS service
  #
  # @!attribute id
  #   @return [Integer] discharge type id - one of '1', '2', '3', '4', '5', '6' or '7'
  # @!attribute description
  #   @return [String] discharge type description
  #
  class DischargeType < Common::Base
    attribute :id, Integer
    attribute :description, String

    # Sort operator
    # Default sort should be by description ascending
    #
    # @return [Integer] -1, 0, or 1
    #
    def <=>(other)
      description <=> other.description
    end
  end
end
