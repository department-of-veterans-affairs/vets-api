# frozen_string_literal: true

require 'vets/model'

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
  class Cemetery
    include Vets::Model

    attribute :cemetery_type, String
    attribute :name, String
    attribute :num, String

    default_sort_by name: :asc

    # Alias of #num
    # @return [String] cemetery number
    #
    def id
      num
    end
  end
end
