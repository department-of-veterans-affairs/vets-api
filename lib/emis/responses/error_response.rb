# frozen_string_literal: true

require 'emis/responses/response'

module EMIS
  module Responses
    class ErrorResponse < EMIS::Responses::Response
      attr_reader :error

      def initialize(error)
        @error = error
      end

      def error?
        true
      end
    end
  end
end
