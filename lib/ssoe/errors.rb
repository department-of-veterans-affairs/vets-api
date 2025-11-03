# frozen_string_literal: true

module SSOe
  module Errors
    # Base error class for SSOe errors
    class ServiceError < StandardError
      attr_reader :status, :body, :fault_code

      def initialize(message = nil, status: nil, body: nil, fault_code: nil)
        super(message)
        @status = status
        @body = body
        @fault_code = fault_code
      end
    end

    class SOAPParseError < ServiceError; end
    class SOAPFaultError < ServiceError; end
    class RequestError < ServiceError; end
    class ConnectionError < ServiceError; end
    class TimeoutError < ServiceError; end
    class UnknownError < ServiceError; end
  end
end
