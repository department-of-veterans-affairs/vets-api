# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    # Internal Server Error - all exceptions not readily accounted fall into this tier
    class InternalServerError < BaseError
      attr_reader :exception

      def initialize(exception)
        raise ArgumentError, 'an exception must be provided' unless exception.is_a?(Exception)

        @exception = exception
      end

      def errors
        meta = { exception: exception.message, backtrace: exception.backtrace } unless ::Rails.env.production?
        Array(SerializableError.new(i18n_data.merge(meta:)))
      end
    end
  end
end
