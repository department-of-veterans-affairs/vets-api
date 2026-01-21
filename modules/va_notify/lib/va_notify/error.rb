# frozen_string_literal: true

module VANotify
  class Error < StandardError
    attr_reader :status_code, :body, :errors, :context

    def self.from_generic_error(error, context = {})
      case error.status
      when 400
        VANotify::BadRequest.new(error.status, error.body, context)
      when 401
        VANotify::Unauthorized.new(error.status, error.body, context)
      when 403
        VANotify::Forbidden.new(error.status, error.body, context)
      when 404
        VANotify::NotFound.new(error.status, error.body, context)
      when 429
        VANotify::RateLimitExceeded.new(error.status, error.body, context)
      when 500
        VANotify::ServerError.new(error.status, error.body, context)
      else
        VANotify::Error.new(error.status, error.body, context)
      end
    end

    def initialize(status_code, body, context = {})
      @status_code = status_code
      @body = body
      @context = context
      super(build_message)
    end

    private

    def build_message
      base_message = body.is_a?(String) ? body : parse_body
      context_message = context.map { |key, value| "#{key}: #{value}" }.join(', ')
      [base_message, context_message].reject(&:empty?).join(' | ')
    end

    def parse_body
      @errors = if body['errors']
                  body.fetch('errors')
                      .map { |e| "#{e.fetch('error')}: #{e.fetch('message')}" }
                      .join(', ')
                else
                  body['message']
                end
    end
  end

  class BadRequest < Error; end
  class Unauthorized < Error; end
  class Forbidden < Error; end
  class NotFound < Error; end
  class RateLimitExceeded < Error; end
  class ServerError < Error; end
end
