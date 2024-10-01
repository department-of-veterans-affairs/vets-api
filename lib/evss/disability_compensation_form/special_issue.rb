# frozen_string_literal: true

require 'vets/model'

module EVSS
  module DisabilityCompensationForm
    class SpecialIssue < Vets::Model
      # Model for parsed special issues such as POW status or PTSD.
      #
      # @!attribute code
      #   @return [String] The lookup code for the issue.
      # @!attribute name
      #   @return [String] The name of the issue.
      #
      attribute :code, String
      attribute :name, String
    end
  end
end
