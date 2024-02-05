# frozen_string_literal: true

module Crm
  class ErrorHandler
    class ServiceError < StandardError; end

    ERROR_MESSAGES = {
      400 => 'Bad request',
      401 => 'Unauthorized',
      403 => 'Forbidden: You do not have permission to access',
      404 => 'Resource not found',
      400..499 => 'Service Error',
      500..599 => 'Server Error'
    }.freeze

    def self.handle(endpoint, response)
      status = response&.status || 500
      error_message = ERROR_MESSAGES.detect do |range, _message|
        range.is_a?(Range) ? range.include?(status) : range == status
      end&.last

      raise ServiceError, "#{error_message} to #{endpoint}: #{response&.body}" if error_message
    end
  end
end
