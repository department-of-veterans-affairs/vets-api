# frozen_string_literal: true

require 'common/schema_checker'

class UpstreamSchemaValidationJob
  include Sidekiq::Job

  sidekiq_options(unique_for: 30.minutes, retry: false)

  def perform(response, schema)
    Common::SchemaChecker.new(response, schema).validate
  end
end