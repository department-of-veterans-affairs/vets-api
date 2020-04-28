# frozen_string_literal: true

include ActiveModel::Serialization
module VeteranVerification
  class TotalDisabilityRatingSerializer < ActiveModel::Serializer
    type :disability_ratings

    attribute :overall_disability_rating
    attribute :test

    def id
      nil
    end

    def overall_disability_rating
      object[:disability_rating_record][:service_connected_combined_degree]
    end

    def ratings
      object[:disability_rating_record][:ratings]
    end

    def test
      object[:disability_rating_record][:ratings]
    end
  end
end
