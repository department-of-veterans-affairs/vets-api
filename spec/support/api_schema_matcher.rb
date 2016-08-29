# frozen_string_literal: true
RSpec::Matchers.define :match_response_schema do |schema|
  match do |response|
    schema_directory = "#{Dir.pwd}/spec/support/schemas"
    schema_path      = "#{schema_directory}/#{schema}.json"
    schema           = File.read(schema_path)
    JSON::Validator.validate!(schema_path, response.body, strict: true)
  end
end

# with the `:strict` option, all properties are condisidered to have `"required": true`
# and all objects `"additionalProperties": false`
# That's a little too strict for the existing vets-json-schema schemas, and so we don't use it.
RSpec::Matchers.define :match_vets_schema do |schema|
  match do |data|
    schema_directory = "#{Dir.pwd}/app/vets-json-schema/dist"
    schema_path      = "#{schema_directory}/#{schema}.json"
    @errors = JSON::Validator.fully_validate(schema_path, data, validate_schema: true)
    @errors == []
  end

  failure_message do |_actual|
    @errors
  end
end
