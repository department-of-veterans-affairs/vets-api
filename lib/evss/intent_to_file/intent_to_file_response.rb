# frozen_string_literal: true

require 'evss/response'
require 'evss/intent_to_file/intent_to_file'

module EVSS
  module IntentToFile
    ##  # TODO - see if we can remove
    # Model for an ITF response containing a intent to file
    #
    # @param status [Integer] the HTTP status code
    #
    # @!attribute intent_to_file
    #   @return [EVSS::IntentToFile::IntentToFile] An intent to file
    #
    class IntentToFileResponse < EVSS::Response
      attribute :intent_to_file, EVSS::IntentToFile::IntentToFile

      def initialize(status, response = nil)
        super(status, response.body) if response
      end

      ##
      # @return [Boolean] Is the ITF eliglible for caching
      #
      def cache?
        ok? && !intent_to_file.expires_within_one_day?
      end
    end
  end
end
