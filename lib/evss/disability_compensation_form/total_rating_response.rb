# frozen_string_literal: true

require 'evss/response'
require 'evss/disability_compensation_form/total_rating'

module EVSS
  module DisabilityCompensationForm
    # Model that contains an array*** of a veteran's parsed total combined disability rating
    #
    # @!attribute rated_disabilities
    #   @return [Array***<EVSS::DisabilityCompensationForm::TotalRating>] The total combined disability rating
    #
    class TotalRatingResponse < EVSS::Response
      attribute :rated_disabilities, Array[EVSS::DisabilityCompensationForm::RatedDisability]
      attribute :total_rating, Array[EVSS::DisabilityCompensationForm::TotalRating]

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
