# frozen_string_literal: true

module Common
  module Client
    # The error class defines the various error types that the client can encounter
    module Errors
      class Error < StandardError; end

      class ClientError < Error
        attr_accessor :status
        attr_accessor :body

        def initialize(error = nil, message: nil, status: nil, body: nil)
          super(message)
          @cause = error
          @status = status
          @body = body
        end

        def errors; end
      end

      class NotAuthenticated < ClientError; end
      class Serialization < ClientError; end
      class ParsingError < ClientError; end

      class HTTPError < ClientError
        alias code status
      end
    end
  end
end
