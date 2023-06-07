# frozen_string_literal: true

require 'json_schema/form_schemas'

module AppealsApi
  class FormSchemas < JsonSchema::FormSchemas
    def initialize(error_type = JsonSchema::JsonApiMissingAttribute, api_name: 'decision_reviews', schema_version: 'v1')
      @api_name = api_name
      @error_type = error_type
      @schema_version = schema_version
    end

    attr_accessor :schema_version, :api_name

    def base_dir
      Rails.root.join('modules', 'appeals_api', Settings.modules_appeals_api.schema_dir, api_name, schema_version)
    end

    def shared_dir(file)
      Rails.root.join('modules', 'appeals_api', Settings.modules_appeals_api.schema_dir, 'shared', schema_version, file)
    end

    def validate!(form, payload)
      resolver = proc do |uri|
        return uri.path unless uri.path.end_with?('.json')

        parsed_schema = JSON.parse File.read shared_dir(uri.path)
        parsed_schema['properties'].values.first
      end

      schema_validator = JSONSchemer.schema(schema(form), insert_property_defaults: true, ref_resolver: resolver)

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
