# frozen_string_literal: true

module Common
  module Client
    # The error class defines the various error types that the client can encounter
    module Errors
      class Error < StandardError; end

      class ClientError < Error
        attr_accessor :status, :body

        def initialize(message = nil, status = nil, body = nil)
          super(message)
          @status = status
          @body = body
        end
      end

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
