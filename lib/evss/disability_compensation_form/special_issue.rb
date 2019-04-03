# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module DisabilityCompensationForm
    # Model for parsed special issues such as POW status or PTSD.
    #
    # @!attribute code
    #   @return [String] The lookup code for the issue.
    # @!attribute name
    #   @return [String] The name of the issue.
    #
    class SpecialIssue
      include Virtus.model

      attribute :code, String
      attribute :name, String
    end
  end
end
