# frozen_string_literal: true

module EVSS
  class ErrorMiddleware < Faraday::Response::Middleware
    class EVSSError < StandardError
      attr_reader :details
      def initialize(message = nil, details = nil)
        super(message)
        @details = details
      end
    end
    class EVSSBackendServiceError < EVSSError; end

    def on_complete(env)
      case env[:status]
      when 200
        resp = env.body
        raise EVSSError.new(resp['messages'], resp['messages']) if resp['success'] == false
        if resp['messages']&.find { |m| m['severity'] =~ /fatal|error/i }
          raise EVSSError.new(resp['messages'], resp['messages'])
        end
      when 503, 504
        resp = env.body
        raise EVSSBackendServiceError, resp
      end
    end
  end
end
