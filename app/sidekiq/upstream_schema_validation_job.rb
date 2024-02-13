# frozen_string_literal: true

require 'schema_contract/validator'

class UpstreamSchemaValidationJob
  include Sidekiq::Job

  sidekiq_options(retry: false)

  def perform(test_name)
    SchemaContract::Validator.new(test_name).validate
  end
end