# frozen_string_literal: true

require 'committee'

Rails.application.config.middleware.use(
  Committee::Middleware::RequestValidation,
  schema_path: Rails.public_path.join('openapi.json').to_s,
  strict_reference_validation: true
)

Rails.application.config.middleware.use(
  Committee::Middleware::ResponseValidation,
  schema_path: Rails.public_path.join('openapi.json').to_s,
  strict_reference_validation: true,
  validate_success_only: true
)
