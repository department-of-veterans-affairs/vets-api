# frozen_string_literal: true

module EventBusGateway
  module Errors
    # Raised when MPI profile lookup fails
    class MpiProfileNotFoundError < StandardError; end

    # Raised when BGS person lookup fails
    class BgsPersonNotFoundError < StandardError; end

    # Raised when notification jobs fail to enqueue
    class NotificationEnqueueError < StandardError; end

    # Raised when ICN lookup fails or returns blank
    class IcnNotFoundError < StandardError; end
  end
end
