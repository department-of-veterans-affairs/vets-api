# frozen_string_literal: true

require 'vets/model'

module DisabilityCompensation
  module ApiProvider
    class SpecialIssue
      include Vets::Model
      attribute :code, String
      attribute :name, String
    end

    class RatedDisability
      include Vets::Model

      attribute :decision_code, String
      attribute :decision_text, String
      attribute :diagnostic_code, Integer
      attribute :hyphenated_diagnostic_code, Integer
      attribute :name, String
      attribute :effective_date, DateTime
      attribute :rated_disability_id, String
      attribute :rating_decision_id, String
      attribute :rating_percentage, Integer
      attribute :maximum_rating_percentage, Integer
      attribute :related_disability_date, DateTime
      attribute :special_issues, DisabilityCompensation::ApiProvider::SpecialIssue, array: true
    end

    class RatedDisabilitiesResponse
      include Vets::Model

      attribute :rated_disabilities, DisabilityCompensation::ApiProvider::RatedDisability, array: true
    end
  end
end
