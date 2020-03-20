# frozen_string_literal: true

# require_relative './json_schema/json_api_missing_attribute'

module JsonSchema
  class FormSchemas
    BASE_DIR = Rails.root.join('modules', 'appeals_api', Settings.appeals.schema_dir)

    SCHEMAS = lambda do
      return_val = {}

      Dir.glob(File.join(BASE_DIR, '/*')).each do |schema|
        schema_name = File.basename(schema, '.json').upcase
        return_val[schema_name] = MultiJson.load(File.read(schema))
      end

      return_val
    end.call

    def self.validate!(form, payload)
      schema_validator = JSONSchemer.schema(SCHEMAS[form], insert_property_defaults: true)
      # there is currently a bug in the gem
      # that it runs the logic based validations
      # before inserting defaults
      # this is a work around
      schema_validator.validate(payload).count
      errors = schema_validator.validate(payload).to_a
      raise JsonSchema::JsonApiMissingAttribute, errors unless errors.empty?

      true
    end
  end
end

