# frozen_string_literal: true
module Common
  module Exceptions
    # InvalidSortCriteria - sort criteria is invalid
    class InvalidSortCriteria < BaseError
      attr_reader :resource, :sort_criteria

      def initialize(resource, sort_criteria)
        @sort_criteria = sort_criteria
        @resource = resource
      end

      def errors
        detail = "\"#{sort_criteria}\" is not a valid sort criteria for \"#{resource}\""
        Array(SerializableError.new(MinorCodes::INVALID_SORT_CRITERIA.merge(detail: detail)))
      end
    end
  end
end
