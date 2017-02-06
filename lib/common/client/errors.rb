# frozen_string_literal: true
module Common
  module Client
    # The error class defines the various error types that the client can encounter
    module Errors
      class Error < StandardError; end

      class ClientError < Error; end
      class NotAuthenticated < ClientError; end
      class Serialization < ClientError; end
      class HTTPError < ClientError
        attr_accessor :code

        def initialize(message = nil, code = nil)
          super(message)
          @code = code
        end
      end
    end
  end
end
