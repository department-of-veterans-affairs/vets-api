# frozen_string_literal: true

module ClaimsApi
  module BGSClient
    class Error < StandardError
      class ConnectionError < self
        # These will all have a `cause` that is a Faraday error.
        delegate :message, to: :cause, allow_nil: true
      end

      ConnectionFailed = Class.new(ConnectionError)
      SSLError = Class.new(ConnectionError)
      TimeoutError = Class.new(ConnectionError)

      class BGSFault < self
        attr_reader :code, :detail # and :message is inherited.

        def initialize(code:, message:, detail:)
          @code = code
          @detail = detail
          super(message)
        end
      end
    end
  end
end
