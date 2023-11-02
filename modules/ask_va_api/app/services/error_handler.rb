# frozen_string_literal: true

class ErrorHandler
  def self.handle_service_error(error)
    error_class = error.class.name
    raise ServiceError, "#{error_class}: #{error.message}"
  end

  class ServiceError < StandardError; end
end
