# frozen_string_literal: true

require 'evss/response'
require 'evss/ppiu/payment_information'

module EVSS
  module PPIU
    ##
    # Model for payment information responses.
    #
    # @param status [Integer] The HTTP status code
    # @param response [Hash] The API response
    #
    # @!attribute responses
    #   @return [Array[EVSS::PPIU::PaymentInformation]] An array of payment information objects
    #
    class PaymentInformationResponse < EVSS::Response
      attribute :responses, EVSS::PPIU::PaymentInformation, array: true, default: []

      def initialize(status, response = nil)
        super(status, response.body) if response
      end
    end
  end
end
