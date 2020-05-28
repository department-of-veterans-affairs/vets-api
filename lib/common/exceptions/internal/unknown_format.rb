# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions::Internal
    # Routing Error - if route is invalid
    class UnknownFormat < Common::Exceptions::BaseError
      attr_reader :format

      def initialize(format = nil)
        @format = format
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_interpolated(detail: { format: @format })))
      end
    end
  end
end
