# frozen_string_literal: true

module MPI
  module Errors
    class Base < StandardError; end
    class RecordNotFound < MPI::Errors::Base; end
    class ArgumentError < MPI::Errors::Base; end

    class ServiceError < MPI::Errors::Base
      attr_reader :body

      def initialize(body = nil)
        @body = body
        super
      end
    end

    class FailedRequestError < MPI::Errors::ServiceError; end
    class InvalidRequestError < MPI::Errors::ServiceError; end
    class DuplicateRecords < MPI::Errors::RecordNotFound; end
  end
end
