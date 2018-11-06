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
        if env.response_headers['content-type'].downcase.include?('xml')
          resp = Hash.from_xml(env.body)
          inner_resp = resp[resp.keys[0]]
          if %w[fatal error].include?(inner_resp&.dig('messages', 'severity')&.downcase)
            raise EVSSError.new(inner_resp['messages']['text'], inner_resp['messages']['text'])
          end
        else
          resp = env.body
          raise EVSSError.new(resp['messages'], resp['messages']) if resp['success'] == false

          if resp['messages']&.find { |m| m['severity'] =~ /fatal|error/i }
            raise EVSSError.new(resp['messages'], resp['messages'])
          end
        end
      when 503, 504
        resp = env.body
        raise EVSSBackendServiceError, resp
      end
    end
  end
end
