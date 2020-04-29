# frozen_string_literal: true

module VeteranVerification
  class DisabilityRatingSerializer < ActiveModel::Serializer
    include ActiveModel::Serialization

    type :disability_ratings

    attribute :overall_disability_rating
    attribute :ratings

    def id
      nil
    end

    def overall_disability_rating
      object[:disability_rating_record][:service_connected_combined_degree]
    end

    def ratings
      ratings = object[:disability_rating_record][:ratings].map do |rating|
        if (rating[:disability_decision_type_name].eql? "Service Connected")
          Rating.new(
            decision: rating[:disability_decision_type_name],
            effective_date: rating[:begin_date],
            rating_percentage: rating[:diagnostic_percent]
          )
        end
      end
      ratings.compact
    end
  end
end
