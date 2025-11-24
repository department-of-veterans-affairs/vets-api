# frozen_string_literal: true

module SSOe
  module Errors
    class Error < StandardError; end
    class RequestError < Error; end
    class ServerError < Error; end
    class ParsingError < Error; end
  end
end
