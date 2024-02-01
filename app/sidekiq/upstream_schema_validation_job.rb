# frozen_string_literal: true

require 'schema_contract/validator'

class UpstreamSchemaValidationJob
  include Sidekiq::Job

  sidekiq_options(unique_for: 30.minutes, retry: false)

  def perform(response, schema)
    SchemaContract::Validator.new(response, schema).validate
  end
end