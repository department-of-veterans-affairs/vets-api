# frozen_string_literal: true

require 'common/exceptions/base_error'
require 'common/exceptions/serializable_error'

module Common
  module Exceptions
    # Parameter Missing - required parameter was not provided
    class NotASafeHostError < BaseError
      attr_reader :host

      def initialize(host)
        @host = host
      end

      def errors
        Array(SerializableError.new(i18n_interpolated(detail: { host: @host })))
      end
    end
  end
end
