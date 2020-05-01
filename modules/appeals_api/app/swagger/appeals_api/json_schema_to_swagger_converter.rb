# frozen_string_literal: true

require_relative './json_schema_reference_string.rb'
require_relative './json_schema_definition_name.rb'

=begin
Converts a restricted-style of JSON Schema to Swagger
  (helps dynamically generated documentation)

must be formatted like this:

  {
    ...
    "$ref": "#/definitions/a",
    ...
    "definitions": {
      ...
    }
  }

There can be more top level keys than just '$ref' and 'definitions',
but this class will ignore them. Therefore, your top level object MUST
be described with a definition.

Example:

  {
    "description": "Example with top-level object defined in '/definitions'",
    "$schema": "http://json-schema.org/draft-07/schema#",
    "$ref": "#/definitions/root",
    "definitions": {
      "root": {
        "type": "object",
        "properties": {
          "data": {
            "$ref": "#/definitions/data"
          },
          "included": {
            "$ref": "#/definitions/included"
          }
        },
        "additionalProperties": false,
        "required": [ "data", "included" ]
      },
      "data": { "type": "string" },
      "included": { "type": "string" }
    }
  }

( You can test out this ^^^ schema here: https://www.jsonschemavalidator.net/ )


This class takes an example like above and converts it to:

  {
    "requestBody": {
      "required": true,
      "content": {
        "application/json": { "schema": '$ref': '#/components/schemas/root' }
      }
    },
    "components": {
      "schemas": {
        "root": {
          "type": "object",
          "properties": {
            "data": {
              "$ref": "#/components/schemas/data"
            },
            "included": {
              "$ref": "#/components/schemas/included"
            }
          },
          "additionalProperties": false,
          "required": [ "data", "included" ]
        },
        "data": { "type": "string" },
        "included": { "type": "string" }
      }
    }
  }

As you can see, the definitions are copied over exactly, but with references
changed to 'components/schemas' instead of 'definitions' (this is accomplished
by recursing through the schema object --not regex).

The only other thing that this class does is remove '$comment' fields --that's it.
*No other conversion is done.* Consequently, to ensure that your JSON Schema is
valid Swagger, there are things you have to avoid.
This document is a good summary:
https://swagger.io/docs/specification/data-models/keywords/

Note: In converting my original JSON Schemas to Swagger-friendly style, the only
thing I needed to change was swapping my consts to enums.
=end

module AppealsApi
  class JsonSchemaToSwaggerConverter
    TOP_LEVEL_SCHEMA_PROPERTIES = %w[type properties additionalProperties required].freeze
    TOP_LEVEL_PROPERTIES = (TOP_LEVEL_SCHEMA_PROPERTIES + %w[$schema description definitions]).freeze

    def initialize(json_schema)
      @json_schema = json_schema
    end

    def to_swagger
      {
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: {
                '$ref': swagger_style_reference(json_schema['$ref'])
              }
            }
          }
        },
        components: {
          schemas: fix_refs_and_remove_comments(json_schema['definitions'])
        }
      }.as_json
    end

    private

    attr_reader :json_schema, :prefix

    def fix_refs_and_remove_comments(value)
      case value
      when Hash
        value.reduce({}) do |new_hash, (k, v)|
          next new_hash if k == '$comment'

          new_v = ref?(k, v) ? swagger_style_reference(v) : fix_refs(v)
          new_hash.merge k => new_v
        end
      when Array
        value.map { |v| fix_refs(v) }
      else
        value
      end
    end

    def ref?(key, val)
      key == '$ref' &&
        JsonSchemaReferenceString.new(val).valid?
    end

    def swagger_style_reference(ref_string)
      JsonSchemaReferenceString.new(ref_string).to_swagger
    end

    def swagger_style_schema_name(key)
      JsonSchemaDefinitionName.new(key).to_swagger
    end
  end
end
