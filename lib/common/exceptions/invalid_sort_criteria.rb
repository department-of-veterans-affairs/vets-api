# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

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
        Array(SerializableError.new(i18n_interpolated(detail: { sort_criteria: @sort_criteria, resource: @resource })))
      end
    end
  end
end
