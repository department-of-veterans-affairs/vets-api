# frozen_string_literal: true

require_relative './json_api_missing_attribute'
require_relative './missing_schema'

module JsonSchema
  class FormSchemas
    def base_dir
      # set in subclass
    end

    def schemas
      @schemas ||= get_schemas
    end

    # safe access (over schemas[]). throws error when trying to access non-existent schema
    def schema(form)
      return schemas[form] if schemas.key? form

      raise JsonSchema::MissingSchema.new(form, schemas.keys)
    end

    def get_schemas
      return_val = {}

      Dir.glob(File.join(base_dir, '/*.json')).each do |schema|
        schema_name = File.basename(schema, '.json').upcase
        return_val[schema_name] = MultiJson.load(File.read(schema))
      end

      return_val
    end

    def validate!(form, payload)
      schema_validator = JSONSchemer.schema(schema(form), insert_property_defaults: true)
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
