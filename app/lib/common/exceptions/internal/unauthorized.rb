# frozen_string_literal: true
module Common
  module Exceptions
    # Unauthorized - We may eventually want different variations on this with distinct MinorCodes
    class Unauthorized < BaseError
      def initialize(options = {})
        @detail = options[:detail]
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(detail: @detail)))
      end
    end
  end
end
