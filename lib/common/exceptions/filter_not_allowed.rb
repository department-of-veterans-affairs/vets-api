# frozen_string_literal: true
module Common
  module Exceptions
    class FilterNotAllowed < BaseError
      attr_reader :filter

      def initialize(filter)
        @filter = filter
      end

      def errors
        detail = "\"#{filter}\" is not allowed for filtering"
        Array(SerializableError.new(MinorCodes::FILTER_NOT_ALLOWED.merge(detail: detail)))
      end
    end
  end
end
