# frozen_string_literal: true

module Common
  module Client
    # The error class defines the various error types that the client can encounter
    module Errors
      class Error < StandardError
        attr_accessor :status
        attr_accessor :body

        def initialize(message = nil, status = nil, body = nil)
          super(message)
          @status = status
          @body = body
        end
      end
      class ConnectionFailed < Error; end

      class ServerError < Error; end

      class ClientError < Error; end
      class NotAuthenticated < ClientError; end
      class Serialization < ClientError; end
      class ParsingError < ClientError; end

      class HTTPError < ClientError
        def initialize(message = nil, status = nil, body = nil)
          super
        end

        alias code status
      end
    end
  end
end
