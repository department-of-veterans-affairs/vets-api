# frozen_string_literal: true

require 'common/exceptions'

module EVSS
  class ErrorMiddleware < Faraday::Response::Middleware
    class EVSSError < StandardError
      attr_reader :details, :body

      def initialize(message = nil, details = nil, body = nil)
        super(message)
        @details = details
        @body = body
      end
    end

    class EVSSBackendServiceError < Common::Exceptions::BackendServiceException; end

    def handle_xml_body(env)
      resp = Hash.from_xml(env.body)
      inner_resp = resp[resp.keys[0]]
      if %w[fatal error].include?(inner_resp&.dig('messages', 'severity')&.downcase)
        raise EVSSError.new(inner_resp['messages']['text'], inner_resp['messages']['text'])
      end
    end

    def on_complete(env)
      status = env[:status]
      resp = env.body
      Raven.extra_context(body: resp)
      case status
      when 200
        if env.response_headers['content-type'].downcase.include?('xml')
          handle_xml_body(env)
        elsif resp['success'] == false || resp['messages']&.find { |m| m['severity'] =~ /fatal|error/i }
          raise EVSSError.new(resp['messages'], resp['messages'], resp)
        end
      when 503, 504
        raise EVSSBackendServiceError.new("EVSS#{status}", { status: }, status, resp)
      end
    end
  end
end
