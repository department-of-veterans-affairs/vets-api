# frozen_string_literal: true

module Logging
  # Proxy class to allow a custom `caller_location` to be used
  class CallLocation
    attr_accessor :base_label, :path, :lineno

    # create proxy caller_location
    # @see Thread::Backtrace::Location
    # @see Logging::Monitor#parse_caller
    def initialize(function = nil, file = nil, line = nil)
      @base_label = function
      @path = file
      @lineno = line
    end

    # create proxy caller_location, default to standard values
    # @see Thread::Backtrace::Location
    # @see Logging::Monitor#parse_caller
    #
    # @param call_location [Logging::CallLocation | Thread::Backtrace::Location] location to be logged as failure point
    #
    # @return Logging::CallLocation
    def self.customize(call_location, function: nil, file: nil, line: nil)
      new(
        function || call_location.base_label,
        file || call_location.path,
        line || call_location.lineno
      )
    end
  end
end
