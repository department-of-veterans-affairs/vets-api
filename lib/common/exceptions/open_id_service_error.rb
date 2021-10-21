# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    # Validation Error - an ActiveModel having validation errors, can be sent to this exception
    class OpenIdServiceError < BaseError
      attr_reader :detail, :code, :status

      def initialize(options = {})
        @detail = options[:detail]
        @code = options[:code]
        @status = options[:status]
        @source = options[:source]
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(detail: @detail, code: @code, status: @status, source: @source)))
      end
    end
  end
end
