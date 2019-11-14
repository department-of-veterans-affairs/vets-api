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
      # attribute :rating_info, Array[EVSS::DisabilityCompensationForm::RatingInfo]
      attribute :disability_decision_type_name, String
      attribute :service_connected_combined_degree, String
      attribute :user_percent_of_disability, String

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
