# frozen_string_literal: true

require 'common/schema_validator'

class UpstreamSchemaValidationJob
  include Sidekiq::Job

  sidekiq_options(unique_for: 30.minutes, retry: false)

  def perform(response, schema)
    Common::SchemaValidator.new(response, schema).validate
  end
end