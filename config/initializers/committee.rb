# frozen_string_literal: true

schema_path = Rails.public_path.join('openapi.json').to_s

Rails.application.config.middleware.use(
  Committee::Middleware::RequestValidation,
  schema_path:,
  parse_response_by_content_type: true,
  check_content_type: true,
  coerce_query_params: true,
  coerce_form_params: true,
  coerce_date_times: true,
  strict_reference_validation: true,
  strict: false # IMPORTANT for rollout: endpoints not in the spec bypass validation!!
)

Rails.application.config.middleware.use(
  Committee::Middleware::ResponseValidation,
  schema_path:,
  parse_response_by_content_type: true
)
