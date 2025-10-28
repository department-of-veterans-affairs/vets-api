# frozen_string_literal: true

require 'committee'
require 'committee/unprocessable_entity_error'

Rails.application.config.middleware.use(
  Committee::Middleware::RequestValidation,
  schema_path: Rails.public_path.join('openapi.json').to_s,
  strict_reference_validation: true,
  raise: false,
  error_class: Committee::UnprocessableEntityError
)

Rails.application.config.middleware.use(
  Committee::Middleware::ResponseValidation,
  schema_path: Rails.public_path.join('openapi.json').to_s,
  strict_reference_validation: true,
  validate_success_only: true,
  raise: false,
  error_class: Committee::UnprocessableEntityError
)
