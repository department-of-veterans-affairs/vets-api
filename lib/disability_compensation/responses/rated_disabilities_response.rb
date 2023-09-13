# frozen_string_literal: true

module DisabilityCompensation
  module ApiProvider
    class SpecialIssue
      include Virtus.model

      attribute :code, String
      attribute :name, String
    end

    class RatedDisability
      include ActiveModel::Serialization
      include Virtus.model

      attribute :decision_code, String
      attribute :decision_text, String
      attribute :diagnostic_code, Integer
      attribute :name, String
      attribute :effective_date, DateTime
      attribute :rated_disability_id, String
      attribute :rating_decision_id, String
      attribute :rating_percentage, Integer
      attribute :maximum_rating_percentage, Integer
      attribute :related_disability_date, DateTime
      attribute :special_issues, Array[DisabilityCompensation::ApiProvider::SpecialIssue]
    end

    class RatedDisabilitiesResponse
      include ActiveModel::Serialization
      include Virtus.model

      attribute :rated_disabilities, Array[DisabilityCompensation::ApiProvider::RatedDisability]
    end
  end
end
