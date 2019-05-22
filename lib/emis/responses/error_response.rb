# frozen_string_literal: true

require 'emis/responses/response'

module EMIS
  module Responses
    # EMIS response that contains a raised error
    class ErrorResponse < EMIS::Responses::Response
      attr_reader :error

      # @param error [StandardError] Error that was raised
      def initialize(error)
        @error = error
      end

      # Error identifier method, always returns true
      # @returns [Boolean]
      def error?
        true
      end
    end
  end
end
