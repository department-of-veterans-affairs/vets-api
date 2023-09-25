# frozen_string_literal: true

class ErrorHandler
  ERROR_MAPPING = {
    'BadRequestError' => 'Bad Request Error',
    'UnauthorizedError' => 'Unauthorized Error',
    'ForbiddenError' => 'Forbidden Error',
    'NotFoundError' => 'Not Found Error',
    'ClientError' => 'Client Error',
    'ServerError' => 'Server Error'
  }.freeze

  def self.handle_service_error(error)
    error_key = error.class.name.split('::').last
    raise ServiceError, "#{ERROR_MAPPING[error_key]}: #{error.message}"
  end

  class ServiceError < StandardError; end
end
