# frozen_string_literal: true

require 'common/models/base'

module EVSS
  module DisabilityCompensationForm
    class RatedDisability
      include Virtus.model

      attribute :decision_code, String
      attribute :decision_text, String
      attribute :diagnostic_code, Integer
      attribute :diagnostic_text, String
      attribute :effective_date, DateTime
      attribute :rated_disability_id, String
      attribute :rating_decision_id, String
      attribute :rating_percentage, Integer
      attribute :related_disability_date, DateTime
      attribute :special_issues, Array[Hash]

    end
  end
end
