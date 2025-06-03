# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'evss/response'
require_relative 'letter'

module EVSS
  module Letters
    ##
    # Model for a letter service response, containing the recipient's name
    # and an array of letter objects
    #
    # @param status [Integer] The HTTP status code
    # @param response [Hash] The API response
    #
    # @!attribute letters
    #   @return [Array[EVSS::Letters::Letter]] An array of the user's letters
    # @!attribute full_name
    #   @return [String] The recipient's full name
    #
    class LettersResponse < EVSS::Response
      attribute :letters, EVSS::Letters::Letter, array: true, default: []
      attribute :full_name, String

      def initialize(status, response = nil)
        if response
          attributes = {
            letters: response.body['letters'],
            full_name: response.body.dig('letter_destination', 'full_name')
          }
        end
        super(status, attributes)
      end
    end
  end
end
