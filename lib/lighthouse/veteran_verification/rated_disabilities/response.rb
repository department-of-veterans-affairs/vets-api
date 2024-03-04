# frozen_string_literal: true

module VeteranVerification
  class RatedDisability
    include ActiveModel::Serialization
    include Virtus.model

    attribute :decision, String
    attribute :effective_date, String
    attribute :rating_end_date, String
    attribute :rating_percentage, Integer
    attribute :diagnostic_type_code, String
    attribute :diagnostic_type_name, String
    attribute :diagnostic_text, String
    attribute :disability_rating_id, String
  end

  class RatedDisabilitiesResponse
    include ActiveModel::Serialization
    include Virtus.model

    attribute :combined_disability_rating, Integer
    attribute :combined_effective_date, String
    attribute :legal_effective_date, String
    attribute :individual_ratings, Array[VeteranVerification::RatedDisability]

    def filter_by_inactivity!
      individual_ratings.select! { |rating| active?(rating) }
    end

    def filter_by_decision!(allowlist)
      individual_ratings.select! do |rating|
        allowlist.include?(rating['decision'])
      end
    end

    def active?(rating)
      date = rating['rating_end_date']

      date.nil? || Date.parse(date).future?
    end
  end
end
