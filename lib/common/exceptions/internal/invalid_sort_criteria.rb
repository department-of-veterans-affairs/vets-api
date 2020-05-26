# frozen_string_literal: true

module Common
  module Exceptions::Internal
    # InvalidSortCriteria - sort criteria is invalid
    class InvalidSortCriteria < Common::Exceptions::BaseError
      attr_reader :resource, :sort_criteria

      def initialize(resource, sort_criteria)
        @sort_criteria = sort_criteria
        @resource = resource
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_interpolated(detail: { sort_criteria: @sort_criteria, resource: @resource })))
      end
    end
  end
end
