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
        Array(SerializableError.new(i18n_interpolated(detail: { id: @id })))
      end
    end
  end
end
