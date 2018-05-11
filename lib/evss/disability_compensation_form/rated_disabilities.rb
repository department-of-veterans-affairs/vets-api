# frozen_string_literal: true

require 'common/models/base'
require 'evss/disability_compensation_form/special_issue'

module EVSS
  module DisabilityCompensationForm
    class RatedDisability
      include Virtus.model

      attribute :decision_code, String
      attribute :decision_text, String
      attribute :diagnostic_code, Integer
      attribute :name, String
      attribute :effective_date, DateTime
      attribute :rated_disability_id, String
      attribute :rating_decision_id, String
      attribute :rating_percentage, Integer
      attribute :related_disability_date, DateTime
      attribute :special_issues, Array[EVSS::DisabilityCompensationForm::SpecialIssue]

      # We map `diagnostic_text` to `name` in order to match the same
      # attribute in the `submit` endpoint
      def initialize(attrs)
        super(attrs)
        self.name = attrs['diagnostic_text']
      end
    end
  end
end
