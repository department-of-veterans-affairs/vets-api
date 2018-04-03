# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module DisabilityCompensationForm
    class SpecialIssue
      include Virtus.model

      attribute :code, String
      attribute :name, String
    end
  end
end
