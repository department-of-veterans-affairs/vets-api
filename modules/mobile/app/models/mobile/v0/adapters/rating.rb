# frozen_string_literal: true

require 'common/models/base'
require 'date'

module Mobile
  module V0
    module Adapters
      class Rating
        def disability_ratings(response)
          Mobile::V0::Rating.new(
            id: 0,
            combined_disability_rating: response[:disability_rating_record][:service_connected_combined_degree].to_i,
            combined_effective_date:
                get_formatted_date(response[:disability_rating_record][:combined_degree_effective_date]),
            legal_effective_date: get_formatted_date(response[:disability_rating_record][:legal_effective_date]),
            individual_ratings: individual_ratings(response)
          )
        end

        private

        def individual_ratings(response)
          if response[:disability_rating_record][:ratings].instance_of?(Hash)
            ratings = [response[:disability_rating_record][:ratings]]
            response[:disability_rating_record][:ratings] = ratings
          elsif response[:disability_rating_record][:ratings].instance_of?(NilClass)
            response[:disability_rating_record][:ratings] = []
          end
          ratings = response[:disability_rating_record][:ratings].map do |rating|
            Mobile::V0::IndividualRating.new(
              decision: rating[:disability_decision_type_name],
              effective_date: get_formatted_date(rating[:begin_date]),
              rating_percentage: rating[:diagnostic_percent].to_i,
              diagnostic_text: rating[:diagnostic_text],
              type: rating[:diagnostic_type_name]
            )
          end
          filtered_ratings = ratings.select do |rating|
            (rating[:decision].eql? 'Service Connected')
          end
          filtered_ratings.compact
        end

        def get_formatted_date(rating_date)
          if rating_date.nil?
            nil
          else
            DateTime.strptime(rating_date, '%m%d%Y')
          end
        end
      end
    end
  end
end
