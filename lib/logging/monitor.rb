# frozen_string_literal: true

module Logging
  class Monitor
    def initialize(service)
      @service = service
    end

    ##
    # log GET request
    #
    # @param error_level [String]
    # @param message [String]
    # @param metric [String]
    # @param additional_context [Hash]
    #
    def track_request(error_level, message, metric, additional_context, call_location: nil)
      function, file, line = parse_caller(call_location)

      StatsD.increment(metric, tags: additional_context[:tags])

      if %w[debug info warn error fatal unknown].include?(error_level)
        Rails.logger.public_send(error_level, message.to_s,
                                 {
                                   statsd: metric,
                                   service:,
                                   user_account_uuid: additional_context[:user_account_uuid],
                                   function:,
                                   file:,
                                   line:,
                                   additional_context:
                                 })
      else
        Rails.logger.error("Invalid log error_level: #{error_level}")
      end
    end

    private

    attr_reader :service

    def parse_caller(call_location)
      call_location ||= caller_locations.second
      [call_location.base_label, call_location.path, call_location.lineno]
    end
  end
end
