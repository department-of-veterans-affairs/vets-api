# frozen_string_literal: true

module Logging
  class Monitor < ::ZeroSilentFailures::Monitor
    def initialize(service)
      @service = service
      super(@service)
    end

    ##
    # log GET request
    #
    # @param message [String]
    # @param metric [String]
    # @param form_type [String]
    # @param user_account_uuid [User]
    #
    def track_request(message, metric, form_type = 'Unknown Form Type', user_account_uuid = nil, call_location: nil)
      function, file, line = parse_caller(call_location)

      StatsD.increment(metric)
      Rails.logger.error("#{form_type} #{message}",
                         {
                           statsd: metric,
                           user_account_uuid:,
                           function:,
                           file:,
                           line:
                         })
    end
  end
end
