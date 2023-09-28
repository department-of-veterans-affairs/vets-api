# frozen_string_literal: true

module Dynamics
  class ErrorHandler
    class ServiceError < StandardError; end
    class BadRequestError < ServiceError; end
    class UnauthorizedError < ServiceError; end
    class ForbiddenError < ServiceError; end
    class NotFoundError < ServiceError; end
    class ClientError < ServiceError; end
    class ServerError < ServiceError; end

    ERROR_CLASSES = {
      400 => BadRequestError,
      401 => UnauthorizedError,
      403 => ForbiddenError,
      404 => NotFoundError,
      400..499 => ClientError,
      500..599 => ServerError
    }.freeze

    def self.handle(endpoint, response)
      return raise ServiceError, "No response received from #{endpoint}" if response.nil?

      error_class = ERROR_CLASSES.detect { |k, _| k == response.status }&.last
      raise error_class, formatted_error_message(endpoint, response) if error_class
    end

    def self.formatted_error_message(endpoint, response)
      return "No response received from #{endpoint}" if response.nil?

      base_message = case response.status
                     when 400 then 'Bad request to'
                     when 401 then 'Unauthorized request to'
                     when 403 then 'Forbidden: You do not have permission to access'
                     when 404 then 'Resource not found at'
                     else 'Error on request to'
                     end
      "#{base_message} #{endpoint}: #{response.body}"
    end
  end
end
