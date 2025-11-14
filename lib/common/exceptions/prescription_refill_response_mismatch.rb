# frozen_string_literal: true

require 'common/exceptions/bad_gateway'

module Common
  module Exceptions
    # Raised when the prescription refill response count does not match the request count
    class PrescriptionRefillResponseMismatch < BadGateway
      def initialize(sent_count, received_count)
        super()
        @sent_count = sent_count
        @received_count = received_count
      end

      def errors
        detail_message = "Refill response count mismatch: sent #{@sent_count} orders, " \
                         "received #{@received_count} responses"
        Array(SerializableError.new(i18n_data.merge(
                                      detail: detail_message,
                                      meta: { sent_count: @sent_count, received_count: @received_count }
                                    )))
      end
    end
  end
end
