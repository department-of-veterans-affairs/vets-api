# frozen_string_literal: true

require 'digital_forms_api/service/request_schema'

Rails.application.config.after_initialize do
  next if Rails.env.test?

  DigitalFormsApi::Service::RequestSchema.new.fetch
rescue => e
  Rails.logger.warn("DigitalFormsApi OpenAPI preload failed: #{e.class}: #{e.message}")
end
