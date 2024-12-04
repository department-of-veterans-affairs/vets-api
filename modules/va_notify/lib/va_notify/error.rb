# frozen_string_literal: true

module VANotify
  class Error < StandardError
    attr_reader :status_code, :body, :errors

    def self.from_generic_error(error)
      case error.status
      when 400
        VANotify::BadRequest.new(error.status, error.body)
      when 401
        VANotify::Unauthorized.new(error.status, error.body)
      when 403
        VANotify::Forbidden.new(error.status, error.body)
      when 404
        VANotify::NotFound.new(error.status, error.body)
      when 429
        VANotify::RateLimitExceeded.new(error.status, error.body)
      when 500
        VANotify::ServerError.new(error.status, error.body)
      else
        VANotify::Error.new(error.status, error.body)
      end
    end

    def initialize(status_code, body)
      @status_code = status_code
      @body = body
      super(build_message)
    end

    private

    def build_message
      return body if body.is_a?(String)

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
