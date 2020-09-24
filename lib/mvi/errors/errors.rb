# frozen_string_literal: true

module MVI
  module Errors
    class Base < StandardError; end
    class RecordNotFound < MVI::Errors::Base; end

    class ServiceError < MVI::Errors::Base
      attr_reader :body
      def initialize(body = nil)
        @body = body
        super
      end
    end

    class FailedRequestError < MVI::Errors::ServiceError; end
    class InvalidRequestError < MVI::Errors::ServiceError; end
    class DuplicateRecords < MVI::Errors::RecordNotFound; end
  end
end
