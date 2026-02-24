# frozen_string_literal: true

require 'digital_forms_api/service/request_schema'

Rails.application.config.after_initialize do
  next if Rails.env.test?

  request_schema_settings = Settings.digital_forms_api.request_schema
  preload_on_boot = request_schema_settings&.preload_on_boot.nil? || ActiveModel::Type::Boolean.new.cast(request_schema_settings.preload_on_boot)

  next unless preload_on_boot

  DigitalFormsApi::Service::RequestSchema.new.fetch
rescue => e
  Rails.logger.warn("DigitalFormsApi request schema preload failed: #{e.class}: #{e.message}")
end
