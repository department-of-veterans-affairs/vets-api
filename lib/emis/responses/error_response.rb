require 'emis/responses/response'

module EMIS
  module Responses
    class ErrorResponse < EMIS::Responses::Response
      def initialize(error)
        @error = error
      end
    end
  end
end
