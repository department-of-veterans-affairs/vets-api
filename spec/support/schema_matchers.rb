# frozen_string_literal: true
require 'rspec/expectations'

module SchemaMatchers
  extend RSpec::Matchers::DSL

  def valid_against_schema?(json, schema_name)
    schema_directory = "#{Dir.pwd}/spec/support/schemas"
    schema_path = "#{schema_directory}/#{schema_name}.json"
    JSON::Validator.validate!(schema_path, json, strict: true)
  end

  matcher :match_schema do |schema_name|
    match { |json| valid_against_schema?(json, schema_name) }
  end

  matcher :match_response_schema do |schema_name|
    match { |response| valid_against_schema?(response.body, schema_name) }
  end

  matcher :match_vets_schema do |schema|
    match do |data|
      @errors = JSON::Validator.fully_validate(VetsJsonSchema::SCHEMAS[schema], data, validate_schema: true)
      @errors.empty?
    end

    failure_message do |_actual|
      @errors
    end
  end
end
