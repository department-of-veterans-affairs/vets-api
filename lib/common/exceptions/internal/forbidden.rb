# frozen_string_literal: true
module Common
  module Exceptions
    # Forbidden
    class Forbidden < BaseError
      def initialize(options = {})
        @detail = options[:detail]
        @code = options[:code] || i18n_field(:code, {})
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(detail: @detail, code: @code)))
      end
    end
  end
end
