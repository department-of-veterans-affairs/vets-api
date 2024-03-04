# frozen_string_literal: true

require 'common/exceptions'

module Chip
  class ErrorMiddleware < Faraday::Middleware
    attr_reader :body, :status

    def on_complete(env)
      return if env.success?

      @status = env[:status].to_i
      @body = env.body
      case status
      when 400..600
        raise Chip::ServiceException.new("CHIP_#{status}", response_values(body), status, body)
      end
    end

    private

    def response_values(body = {})
      {
        status:,
        detail: [JSON.parse(body)],
        code: "CHIP_#{status}"
      }
    end
  end
end

Faraday::Response.register_middleware chip_error: Chip::ErrorMiddleware
