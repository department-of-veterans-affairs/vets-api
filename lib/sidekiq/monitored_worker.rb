# frozen_string_literal: true

module Sidekiq
  module MonitoredWorker
    # this Module is to mark workers as monitored, allowing RetryMonitoring to
    # check against it's existence.
  end
end
