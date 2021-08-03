# frozen_string_literal: true

require 'common/models/base'
require 'date'
require 'common/exceptions'

module VeteranVerification
  module V1
    class DisabilityRating
      include ActiveModel::Serialization
      include Virtus.model

      attribute :id, String
      attribute :combined_disability_rating, Integer
      attribute :combined_effective_date, String
      attribute :legal_effective_date, String
      attribute :individual_ratings, Array

      def self.rating_service
        if Settings.vet_verification.mock_bgs == true
          BGS::MockDisabilityRatingService.new
        else
          BGS::DisabilityRatingService.new
        end
      end

      def self.for_user(user)
        response = rating_service.get_rating(user)
        handle_errors!(response)
        disability_ratings(response)
      end

      def self.handle_errors!(response)
        raise_error! unless response[:disability_rating_record].instance_of?(Hash)
      end

      def self.raise_error!
        raise Common::Exceptions::BackendServiceException.new(
          'BGS_RTG_502',
          source: self.class.to_s
        )
      end

      def self.disability_ratings(response)
        VeteranVerification::V1::DisabilityRating.new(
          id: 0,
          combined_disability_rating: response[:disability_rating_record][:service_connected_combined_degree],
          combined_effective_date:
              get_formatted_date(response[:disability_rating_record][:combined_degree_effective_date]),
          legal_effective_date: get_formatted_date(response[:disability_rating_record][:legal_effective_date]),
          individual_ratings: individual_ratings(response)
        )
      end

      def self.individual_ratings(response)
        if response[:disability_rating_record][:ratings].instance_of?(Hash)
          ratings = [response[:disability_rating_record][:ratings]]
          response[:disability_rating_record][:ratings] = ratings
        elsif response[:disability_rating_record][:ratings].instance_of?(NilClass)
          response[:disability_rating_record][:ratings] = []
        end
        ratings = response[:disability_rating_record][:ratings].map do |rating|
          {
            decision: rating[:disability_decision_type_name],
            effective_date: get_formatted_date(rating[:begin_date]),
            rating_percentage: rating[:diagnostic_percent].to_i
          }
        end
        filtered_ratings = ratings.select do |rating|
          (rating[:decision].eql? 'Service Connected')
        end
        filtered_ratings.compact
      end

      def self.get_formatted_date(rating_date)
        if rating_date.nil?
          nil
        else
          Date.strptime(rating_date, '%m%d%Y')
        end
      end
    end
  end
end
