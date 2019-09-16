# frozen_string_literal: true

module Common
  module Exceptions
    # Parameter Missing - required parameter was not provided
    class AmbiguousRequest < BaseError

      def initialize(detail)
        @detail = detail
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(detail: @detail)))
      end
    end
  end
end
