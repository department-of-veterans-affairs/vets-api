# frozen_string_literal: true
module EVSS
  class ErrorMiddleware < Faraday::Response::Middleware
    class EVSSError < StandardError; end
    class EVSSServiceError < EVSSError; end

    def on_complete(env)
      case env[:status]
      when 200
        resp = env.body
        raise EVSSError, resp['messages'] if resp['success'] == false
        raise EVSSError, resp['messages'] if resp['messages']&.find { |m| m['severity'] =~ /fatal|error/i }
      when 503, 504
        resp = env.body
        raise EVSSServiceError, resp
      end
    end
  end
end
