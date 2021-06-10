# frozen_string_literal: true

require 'json_schema/form_schemas'

module AppealsApi
  class FormSchemas < JsonSchema::FormSchemas
    def initialize(error_type = JsonSchema::JsonApiMissingAttribute, schema_version: 'v1')
      @error_type = error_type
      @schema_version = schema_version
    end

    attr_accessor :schema_version

    def base_dir
      Rails.root.join('modules', 'appeals_api', Settings.modules_appeals_api.schema_dir, schema_version)
    end

    def validate!(form, payload)
      schema_validator = JSONSchemer.schema(schema(form), insert_property_defaults: true)
      # there is currently a bug in the gem
      # that it runs the logic based validations
      # before inserting defaults
      # this is a work around
      schema_validator.validate(payload).count
      errors = schema_validator.validate(payload).to_a
      raise @error_type, errors unless errors.empty?

      true
    end
  end
end
