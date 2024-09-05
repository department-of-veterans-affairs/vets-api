# frozen_string_literal: true

require 'json_schema/form_schemas'

module AppealsApi
  class FormSchemas < JsonSchema::FormSchemas
    # Shared schemas below are maintained as static JSON files
    STATIC_SHARED_SCHEMA_TYPES = %w[
      address
      fileNumber
      icn
      nonBlankString
      phone
      ssn
    ].freeze

    # Shared schemas below are generated dynamically
    GENERATED_SHARED_SCHEMA_TYPES = %w[
      timezone
    ].freeze

    ALL_SHARED_SCHEMA_TYPES = (STATIC_SHARED_SCHEMA_TYPES + GENERATED_SHARED_SCHEMA_TYPES).freeze

    def initialize(error_type = JsonSchema::JsonApiMissingAttribute, api_name: 'decision_reviews', schema_version: 'v1')
      @api_name = api_name
      @error_type = error_type
      @schema_version = schema_version
    end

    attr_accessor :schema_version, :api_name

    def base_dir
      Rails.root.join('modules', 'appeals_api', Settings.modules_appeals_api.schema_dir, api_name, schema_version)
    end

    def self.shared_dir(schema_filename, schema_version)
      Rails.root.join(
        'modules', 'appeals_api', Settings.modules_appeals_api.schema_dir, 'shared', schema_version, schema_filename
      )
    end

    def validate!(form, payload)
      resolver = proc do |uri|
        return uri.path unless uri.path.end_with?('.json')

        schema_type = uri.path.chomp('.json').tr('/', '')
        self.class.load_shared_schema(schema_type, schema_version, strip_description: true)
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

    def self.load_shared_schema(schema_type, schema_version, strip_description: false)
      schema = if schema_type.in?(STATIC_SHARED_SCHEMA_TYPES)
                 JSON.parse(File.read(shared_schema_file_path(schema_type, schema_version)))
               elsif schema_type.in?(GENERATED_SHARED_SCHEMA_TYPES)
                 generated_schemas(schema_version)[schema_type]
               end
      return schema unless strip_description

      schema['properties'].values.first if schema.present?
    end

    def self.shared_schema_file_path(schema_type, schema_version)
      Rails.root.join('modules', 'appeals_api', 'config', 'schemas', 'shared', schema_version, "#{schema_type}.json")
    end

    def self.generated_schemas(schema_version)
      schemas = {
        v0: {
          timezone: {
            '$schema': 'http://json-schema.org/draft-2020-12/schema#',
            description: "JSON Schema for VA Decision Review Forms: 'timezone'",
            properties: {
              timezone: {
                type: 'string',
                enum: TZInfo::Timezone.all_identifiers
              }
            }
          }
        }
      }

      schemas[schema_version.to_sym].with_indifferent_access
    end
  end
end
