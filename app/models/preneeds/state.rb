# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Models US states returned from EOAS service
  #
  # @!attribute code
  #   @return [String] state abbreviation
  # @!attribute name
  #   @return [String] state name
  # @!attribute first_five_zip
  #   @return [String] smallest (numerically) zip code found in state
  # @!attribute last_five_zip
  #   @return [String] largest (numerically) zip code found in state
  # @!attribute lower_indicator
  #   @return [String] lower 48 states indicator - 'Y' or 'N'
  #
  class State < Common::Base
    attribute :code, String
    attribute :name, String
    attribute :first_five_zip, String
    attribute :last_five_zip, String
    attribute :lower_indicator, String

    # Alias of #code
    #
    def id
      code
    end

    # Sort operator. Default sort should be by code ascending
    #
    # @return [Integer] -1, 0, or 1
    #
    def <=>(other)
      code <=> other.code
    end
  end
end
