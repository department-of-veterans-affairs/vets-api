# frozen_string_literal: true

module Common
  module Client
    # The error class defines the various error types that the client can encounter
    module Errors
      class Error < StandardError; end

      class ClientError < Error
        attr_accessor :status
        attr_accessor :body

        def initialize(message = nil, status = nil, body = nil)
          super(message)
          @status = status
          @body = body
        end
      end

      class NotAuthenticated < ClientError; end
      class Serialization < ClientError; end
      class HTTPError < ClientError
        attr_accessor :code

        def initialize(message = nil, code = nil)
          super(message)
          @code = code
        end
      end

      class TooManyRequests < HTTPError
        attr_accessor :headers

        def initialize(headers = nil)
          super('throttled', 429)
          @headers = headers
        end
      end
    end
  end
end
