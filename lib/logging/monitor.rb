# frozen_string_literal: true

require 'zero_silent_failures/monitor'

module Logging
  class Monitor
    include ZeroSilentFailures

    def initialize(service)
      @service = service
    end

    ##
    # log GET request
    #
    # @param message [String]
    # @param metric [String]
    # @param tags [Array]
    # @param context [String]
    # @param user_account_uuid [User]
    #
    def track_request(error_level, message, metric, tags, context, user_account_uuid = nil, call_location: nil) # rubocop:disable Metrics/ParameterLists
      function, file, line = parse_caller(call_location)

      StatsD.increment(metric, tags: ["service:#{@service}", "function:#{function}"].concat(tags || []))

      if %w[debug info warn error fatal unknown].include?(error_level)
        Rails.logger.public_send(error_level, message.to_s,
                                 {
                                   statsd: metric,
                                   user_account_uuid:,
                                   function:,
                                   file:,
                                   line:,
                                   context:
                                 })
      else
        Rails.logger.error("Invalid log error_level: #{error_level}")
      end
    end

    def parse_caller(call_location)
      call_location ||= caller_locations.second
      [call_location.base_label, call_location.path, call_location.lineno]
    end
  end
end
