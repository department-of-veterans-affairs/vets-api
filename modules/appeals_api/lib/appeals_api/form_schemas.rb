# frozen_string_literal: true

require 'json_schema/form_schemas'

module AppealsApi
  class FormSchemas < JsonSchema::FormSchemas
    # TODO: Use Common::Exceptions::DetailedSchemaErrors for more robust errors.
    # HigherLevelReviewsController currently uses JsonSchema::JsonApiMissingAttribute, NOD uses DetailedSchemaErrors
    # HLR will need to wait for a new version to be able to switch to DetailedSchemaErrors
    def initialize(error_type = JsonSchema::JsonApiMissingAttribute)
      @error_type = error_type
    end

    def base_dir
      Rails.root.join('modules', 'appeals_api', Settings.modules_appeals_api.schema_dir)
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
