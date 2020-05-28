# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions::Internal
    class FilterNotAllowed < Common::Exceptions::BaseError
      attr_reader :filter

      def initialize(filter)
        @filter = filter
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_interpolated(detail: { filter: @filter })))
      end
    end
  end
end
