# frozen_string_literal: true

require 'evss/response'
require 'evss/disability_compensation_form/rating_info'

module EVSS
  module DisabilityCompensationForm
    # Model that contains an array*** of a veteran's parsed total combined disability rating
    #
    # @!attribute rated_disabilities
    #   @return [Array***<EVSS::DisabilityCompensationForm::RatingInfo>] The total combined disability rating
    #
    class RatingInfoResponse < EVSS::Response
      #attribute :rating_info, Array[EVSS::DisabilityCompensationForm::RatingInfo]
      attribute :user_percent_of_disability, Integer

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
