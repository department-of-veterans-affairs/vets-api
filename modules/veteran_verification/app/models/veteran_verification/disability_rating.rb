# frozen_string_literal: true

require 'common/models/base'

module VeteranVerification
  class DisabilityRating
    include ActiveModel::Serialization
    include Virtus.model

    attribute :id, String
    attribute :overall_disability_rating, String
    attribute :ratings, Array

    def self.rating_service
      BGS::DisabilityRatingService.new
    end

    def self.for_user(user)
      response = rating_service.get_rating(user)
      disability_ratings(response)
    end

    def self.disability_ratings(response)
      DisabilityRating.new(
        id: 0,
        overall_disability_rating: response[:disability_rating_record][:service_connected_combined_degree],
        ratings: ratings(response)
      )
    end

    def self.ratings(response)
      unless response[:disability_rating_record][:ratings].class.eql? Array
        ratings = [response[:disability_rating_record][:ratings]]
        response[:disability_rating_record][:ratings] = ratings
      end
      ratings = response[:disability_rating_record][:ratings].map do |rating|
        {
          decision: rating[:disability_decision_type_name],
          effective_date: rating[:begin_date],
          rating_percentage: rating[:diagnostic_percent]
        }
      end
      filtered_ratings = ratings.select do |rating|
        (rating[:decision].eql? 'Service Connected')
      end
      filtered_ratings.compact
    end
  end
end
