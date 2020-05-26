# frozen_string_literal: true

module Common
  module Exceptions::Internal
    # Validation Error - an ActiveModel having validation errors, can be sent to this exception
    class TokenValidationError < Common::Exceptions::BaseError
      attr_reader :detail

      def initialize(options = {})
        @detail = options[:detail]
        @source = options[:source]
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_data.merge(detail: @detail, source: @source)))
      end
    end
  end
end
