# frozen_string_literal: true

require_relative './json_schema_reference_string.rb'
require_relative './json_schema_definition_name.rb'

# does very little translation. only does:
#   recursively switches references to Swagger-style
#   recursively removes $comment fields

module AppealsApi
  class JsonSchemaToSwaggerConverter
    TOP_LEVEL_SCHEMA_PROPERTIES = %w[type properties additionalProperties required].freeze
    TOP_LEVEL_PROPERTIES = (TOP_LEVEL_SCHEMA_PROPERTIES + %w[$schema description definitions]).freeze

    def initialize(json_schema, prefix: nil)
      @json_schema = json_schema
      @prefix = prefix

      raise ArgumentError, "#{json_schema.keys} #{TOP_LEVEL_PROPERTIES}" unless valid?
    end

    def to_swagger
      swagger = base_swagger_hash

      json_schema['definitions'].each do |key, val|
        swagger['components']['schemas'][swagger_style_schema_name(key)] = fix_refs(val)
      end

      remove_comments(swagger)
    end

    private

    attr_reader :json_schema, :prefix

    def valid?
      json_schema.keys.length == TOP_LEVEL_PROPERTIES.length &&
        json_schema.keys.all? { |key| TOP_LEVEL_PROPERTIES.include? key }
    end

    def base_swagger_hash
      {
        requestBody: {
          required: true,
          content: {
            'application/json': { schema: fix_refs(top_level_schema) }
          }
        },
        components: { schemas: { } }
      }.as_json
    end

    def top_level_schema
      json_schema.slice(*TOP_LEVEL_SCHEMA_PROPERTIES)
    end

    def fix_refs(value)
      case value
      when Hash
        value.reduce({}) do |new_hash, (k, v)|
          new_v = if k == '$ref' && v.is_a?(String)
                    swagger_style_reference(v)
                  else
                    fix_refs(v)
                  end
          new_hash.merge(k => new_v)
        end
      when Array
        value.map { |v| fix_refs(v) }
      else
        value
      end
    end

    def remove_comments(value)
      case value
      when Hash
        value.reduce({}) do |new_hash, (k, v)|
          if k == '$comment'
            new_hash
          else
            new_hash.merge(k => remove_comments(v))
          end
        end
      when Array
        value.map { |v| remove_comments(v) }
      else
        value
      end
    end

    def swagger_style_reference(ref_string)
      JsonSchemaReferenceString.new(ref_string, prefix: prefix).to_swagger
    end

    def swagger_style_schema_name(key)
      JsonSchemaDefinitionName.new(key, prefix: prefix).to_swagger
    end
  end
end
