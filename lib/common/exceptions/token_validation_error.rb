# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    # Validation Error - an ActiveModel having validation errors, can be sent to this exception
    class TokenValidationError < BaseError
      attr_reader :code, :detail, :status

      def initialize(options = {})
        @code = options[:code] || 401
        @detail = options[:detail]
        @source = options[:source]
        @status = options[:status] || 401
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(code: @code, detail: @detail, source: @source, status: @status)))
      end
    end
  end
end
