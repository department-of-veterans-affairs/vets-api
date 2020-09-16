# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    # InvalidFiltersSyntax - filter keys are invalid
    class InvalidFiltersSyntax < BaseError
      attr_reader :filters

      def initialize(filters, options = {})
        @filters = filters
        @detail = options[:detail] || i18n_field(:detail, filters: @filters)
      end

      def errors
        Array(SerializableError.new(i18n_data.merge(detail: @detail)))
      end
    end
  end
end
