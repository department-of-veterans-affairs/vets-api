# frozen_string_literal: true

module MPI
  module Errors
    class ServiceError < StandardError
      attr_reader :body

      def initialize(body = nil)
        @body = body
        super
      end
    end

    class Response < ServiceError; end
    class InvalidResponseParamsError < StandardError; end
    class RecordNotFound < MPI::Errors::Response; end
    class ArgumentError < MPI::Errors::Response; end
    class DuplicateRecords < MPI::Errors::Response; end
    class AccountLockedError < StandardError; end
    class Request < ServiceError; end
    class FailedRequestError < MPI::Errors::Request; end
    class InvalidRequestError < MPI::Errors::Request; end
  end
end
