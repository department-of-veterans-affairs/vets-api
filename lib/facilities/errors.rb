# frozen_string_literal: true
module Facilities
  module Errors
    class ServiceError < StandardError
    end
    class SerializationError < Facilities::Errors::ServiceError
    end
    class RequestError < Facilities::Errors::ServiceError
      attr_accessor :code

      def initialize(message = nil, code = nil)
        super(message)
        @code = code
      end
    end
  end
end
