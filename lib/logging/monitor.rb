# frozen_string_literal: true

require 'logging/helper/data_scrubber'
require 'logging/helper/parameter_filter'

# Logging
module Logging
  # helper classes
  module Helper; end
  # additional logging functions for specific use cases
  module Include; end
  # extra logging functionality
  module ThirdPartyTransaction; end

  # generic monitoring class
  class Monitor
    include Logging::Helper::DataScrubber
    include Logging::Helper::ParameterFilter

    # allowed logging params
    ALLOWLIST = %w[
      statsd
      service
      function
      line
      context
    ].freeze

    # excluded logging params
    BLOCKLIST = %w[
      file
      ssn
      icn
      edipi
      email
      phone
    ].freeze

    attr_reader :allowlist, :service

    # create a monitor
    #
    # @param service [String] the service name for this monitor; will be included with each log message
    # @param allowlist [Array<String>] the list of allowed parameters
    # @param safe_keys [Array<String>] the list of safe keys whose values can be logged without redaction
    def initialize(service, allowlist: [], safe_keys: [])
      @service = service
      @allowlist = (ALLOWLIST + allowlist.map(&:to_s)).uniq - BLOCKLIST
      @safe_keys = safe_keys
    end

    # perform monitoring actions - StatsD.increment and Rails.logger
    #
    # @param level [String|Symbol] the log level to Rails.logger
    # @param message [String] the message to be logged
    # @param metric [String] the metric to be incremented
    # @param call_location [Logging::CallLocation | Thread::Backtrace::Location] location to be logged as failure point
    # @param context [Mixed] additional parameters to pass to log; if `tags` is provided it will be included in StatsD
    def track_request(level, message, metric, call_location: nil, **context)
      function, file, line = parse_caller(call_location)

      tags = (["service:#{service}", "function:#{function}"] + (context[:tags] || [])).uniq
      StatsD.increment(metric, tags:)

      filtered_context = scrub(filter_params(context, allowlist:), safe_keys: @safe_keys)

      unless %w[debug info warn error fatal unknown].include?(level.to_s)
        Rails.logger.error("#{self.class} Invalid log level: #{level}", service:, function:, file:, line:)
        level = :unknown
      end

      payload = {
        statsd: metric,
        service:,
        function:,
        file:,
        line:,
        context: filtered_context
      }
      Rails.logger.public_send(level, message.to_s, **payload)
    end

    private

    # parse information from the `caller`
    # defaults to the location calling `track_request`
    #
    # @see https://alextaylor.ca/read/caller-tricks/
    # @see https://stackoverflow.com/a/37565500/1812854
    # @see https://ruby-doc.org/core-2.2.3/Thread/Backtrace/Location.html
    #
    # @param call_location [CallLocation | Thread::Backtrace::Location] location to be logged as failure point
    def parse_caller(call_location)
      call_location ||= caller_locations.second
      [call_location.base_label, call_location.path, call_location.lineno]
    end
  end
end
