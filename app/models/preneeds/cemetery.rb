# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Models a cemetery from the EOAS service.
  # For use within the {Preneeds::BurialForm} form.
  #
  # @!attribute cemetery_type
  #   @return [String] cemetery type; one of 'N', 'S', 'I', 'A', 'M'
  # @!attribute name
  #   @return [String] name of cemetery
  # @!attribute num
  #   @return [String] cemetery number
  #
  class Cemetery < Preneeds::Base

    attr_accessor :cemetery_type, :name, :num

    # Alias of #num
    # @return [String] cemetery number
    #
    def id
      num
    end

    # Sort operator. Default sort should be by name ascending
    #
    # @return [Integer] -1, 0, or 1
    #
    def <=>(other)
      name <=> other.name
    end
  end
end
