# frozen_string_literal: true
module EVSS
  class ErrorMiddleware < Faraday::Response::Middleware
    class EVSSError < StandardError; end

    def on_complete(env)
      case env[:status]
      when 200
        resp = env.body
        raise EVSSError, resp['messages'] if resp['success'] == false
        raise EVSSError, resp['messages'] if resp['messages']&.find { |m| m['severity'] =~ /fatal|error/i }
      end
    end
  end
end
