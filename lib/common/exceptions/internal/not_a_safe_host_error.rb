# frozen_string_literal: true

module Common
  module Exceptions::Internal
    # Parameter Missing - required parameter was not provided
    class NotASafeHostError < Common::Exceptions::BaseError
      attr_reader :host

      def initialize(host)
        @host = host
      end

      def errors
        Array(Common::Exceptions::SerializableError.new(i18n_interpolated(detail: { host: @host })))
      end
    end
  end
end
