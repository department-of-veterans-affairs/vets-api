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
      handle_errors!(response)
      disability_ratings(response)
    end

    def self.handle_errors!(response)
      raise_error! unless response[:disability_rating_record][:ratings].is_a?(Array)
    end

    def self.raise_error!
      raise Common::Exceptions::BackendServiceException.new(
        'BGS_RTNGSRVC502',
        source: self.class.to_s
        )
    end

    def self.disability_ratings(response)
      DisabilityRating.new(
        id: 0,
        overall_disability_rating: response[:disability_rating_record][:service_connected_combined_degree],
        ratings: ratings(response),
        )
    end

    def self.ratings(response)
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
