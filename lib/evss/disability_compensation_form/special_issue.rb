# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module DisabilityCompensationForm
    # Model for parsed special issues
    # @!attribute special_issues
    #   @return [Array<EVSS::DisabilityCompensationForm::SpecialIssue>] List of complicating issues e.g. ['POW', 'PTSD_1']
    #
    class SpecialIssue
      include Virtus.model

      attribute :code, String
      attribute :name, String
    end
  end
end
