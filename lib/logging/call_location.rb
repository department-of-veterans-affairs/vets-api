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
  end
end
