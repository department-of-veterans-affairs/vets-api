# frozen_string_literal: true

module Common
  module Exceptions
    # Internal Server Error - all exceptions not readily accounted fall into this tier
    class InternalServerError < BaseError
      attr_reader :error
      
      def initialize(exception)
        super(exception)
        raise ArgumentError, 'an exception must be provided' unless error.is_a?(Exception)
      end

      def errors
        meta = { exception: error.message, backtrace: error.backtrace } unless ::Rails.env.production?
        Array(SerializableError.new(i18n_data.merge(meta: meta)))
      end
    end
  end
end
