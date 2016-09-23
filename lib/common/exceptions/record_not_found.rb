# frozen_string_literal: true
module Common
  module Exceptions
    # Record Not Found - if no record exists having id, or resource having id does not belong to requester
    class RecordNotFound < BaseError
      attr_reader :id

      def initialize(id)
        @id = id
      end

      def errors
        detail = "The record identified by #{id} could not be found"
        Array(SerializableError.new(MinorCodes::RECORD_NOT_FOUND.merge(detail: detail)))
      end
    end
  end
end
