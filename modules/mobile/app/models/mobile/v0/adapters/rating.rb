# frozen_string_literal: true

require 'common/models/base'
require 'date'

module Mobile
  module V0
    module Adapters
      class Rating
        def disability_ratings(combine_response, individual_response)
          Mobile::V0::Rating.new(
            id: 0,
            combined_disability_rating: combine_response[:user_percent_of_disability].to_i,
            individual_ratings: individual_ratings(individual_response)
          )
        end

        private

        def individual_ratings(response)
          response[:rated_disabilities].map do |rating|
            Mobile::V0::IndividualRating.new(
              decision: rating[:decision_text],
              effective_date: rating[:effective_date],
              rating_percentage: rating[:rating_percentage].to_i,
              diagnostic_text: rating[:name]
            )
          end
        end
      end
    end
  end
end
