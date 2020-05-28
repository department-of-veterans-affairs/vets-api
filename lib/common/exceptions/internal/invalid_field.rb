# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions::Internal
    # InvalidField - field is invalid
    class InvalidField < Common::Exceptions::BaseError
      attr_reader :field, :type

      def initialize(field, type)
        @field = field
        @type = type
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_interpolated(detail: { field: @field, type: @type })))
      end
    end
  end
end
