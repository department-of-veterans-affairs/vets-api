# frozen_string_literal: true

require 'committee'
require 'committee/unprocessable_entity_error'

schema_path = Rails.public_path.join('openapi.json').to_s

ERROR_HANDLER = lambda do |ex, env|
  req = Rack::Request.new(env)
  Rails.logger.warn(
    '[Committee] Request validation failed',
    {
      path: req.path,
      method: req.request_method,
      status: 422,
      error_class: ex.class.name.demodulize,
      error_type: ex.is_a?(Committee::InvalidRequest) ? 'request_validation' : 'response_validation'
    }
  )
end

Rails.application.config.middleware.use(
  Committee::Middleware::RequestValidation,
  schema_path:,
  strict_reference_validation: true,
  raise: false,
  error_class: Committee::UnprocessableEntityError,
  error_handler: ERROR_HANDLER
)

Rails.application.config.middleware.use(
  Committee::Middleware::ResponseValidation,
  schema_path:,
  strict_reference_validation: true,
  validate_success_only: true,
  raise: false,
  error_class: Committee::UnprocessableEntityError,
  error_handler: ERROR_HANDLER
)
