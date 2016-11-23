# frozen_string_literal: true
module Common
  module Exceptions
    class FilterNotAllowed < BaseError
      attr_reader :filter

      def initialize(filter)
        @filter = filter
      end

      def errors
        Array(SerializableError.new(i18n_interpolated(detail: { filter: @filter })))
      end
    end
  end
end
