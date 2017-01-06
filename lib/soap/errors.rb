# frozen_string_literal: true
module SOAP
  module Errors
    class ServiceError < StandardError
    end
    class RequestFailureError < SOAP::Errors::ServiceError
    end
    class InvalidRequestError < SOAP::Errors::ServiceError
    end
    class HTTPError < SOAP::Errors::ServiceError
      attr_accessor :code

      def initialize(message = nil, code = nil)
        super(message)
        @code = code
      end
    end
    class RecordNotFound < StandardError
    end
  end
end
