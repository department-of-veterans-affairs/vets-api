# frozen_string_literal: true

module Common
  module Exceptions::Internal
    # Internal Server Error - all exceptions not readily accounted fall into this tier
    class InternalServerError < Common::Exceptions::BaseError
      attr_reader :exception

      def initialize(exception)
        raise ArgumentError, 'an exception must be provided' unless exception.is_a?(Exception)

        @exception = exception
      end

      def errors
        meta = { exception: exception.message, backtrace: exception.backtrace } unless ::Rails.env.production?
        Array(Common::Exceptions::SerializableError.new(i18n_data.merge(meta: meta)))
      end
    end
  end
end
