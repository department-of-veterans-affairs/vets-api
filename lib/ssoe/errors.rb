# frozen_string_literal: true

module SSOe
  module Errors
    class SOAPParseError < StandardError; end
    class SOAPFaultError < StandardError; end
    class RequestError < StandardError; end
    class ConnectionError < StandardError; end
    class TimeoutError < StandardError; end
    class UnknownError < StandardError; end
  end
end
