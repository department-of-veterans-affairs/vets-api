# frozen_string_literal: true

require_relative './json_schema_reference_string'

# Converts a restricted-style of JSON Schema to Swagger
#
# must be formatted like this:
#
#   {
#     ...
#     "$ref": "#/definitions/someNameHere"
#     ...
#     "definitions": {
#       ...
#     }
#   }
#
# There can be more top level keys than just '$ref' and 'definitions',
# but this class will ignore them. Therefore, your top level object MUST
# be described with a definition.
#
# Example:
#
#   {
#     "description": "Example with top-level object defined in '/definitions'",
#     "$schema": "http://json-schema.org/draft-07/schema#",
#     "$ref": "#/definitions/root",
#     "definitions": {
#       "root": {
#         "type": "object",
#         "properties": {
#           "data": {
#             "$ref": "#/definitions/data"
#           },
#           "included": {
#             "$ref": "#/definitions/included"
#           }
#         },
#         "additionalProperties": false,
#         "required": [ "data", "included" ]
#       },
#       "data": { "type": "string" },
#       "included": { "type": "string" }
#     }
#   }
#
# ( You can test out this ^^^ schema here: https://www.jsonschemavalidator.net/ )
#
#
# This class takes an example like above and converts it to:
#
#   {
#     "requestBody": {
#       "required": true,
#       "content": {
#         "application/json": { "schema": '$ref': '#/components/schemas/root' }
#       }
#     },
#     "components": {
#       "schemas": {
#         "root": {
#           "type": "object",
#           "properties": {
#             "data": {
#               "$ref": "#/components/schemas/data"
#             },
#             "included": {
#               "$ref": "#/components/schemas/included"
#             }
#           },
#           "additionalProperties": false,
#           "required": [ "data", "included" ]
#         },
#         "data": { "type": "string" },
#         "included": { "type": "string" }
#       }
#     }
#   }
#
# The definitions are copied over exactly but with references changed to
# 'components/schemas' instead of 'definitions' (this is accomplished by recursing
# through the schema object).
#
# The only other thing that this class does is remove '$comment' fields --that's it.
# *No other conversion is done.* Consequently, to ensure that your JSON Schema is
# valid Swagger, there are things you have to avoid.
# This document is a good summary:
# https://swagger.io/docs/specification/data-models/keywords/
#
# Note: In converting my original JSON Schemas to Swagger-friendly style, the only
# thing I needed to change was swapping my consts to enums.

module AppealsApi
  class JsonSchemaToSwaggerConverter
    class << self
      # recursively change $ref fields to swagger-style
      def refs_to_swagger(value)
        case value
        when Hash
          value.reduce({}) do |new_hash, (k, v)|
            next new_hash.merge(k => JsonSchemaReferenceString.new(v).to_swagger) if k == '$ref'

            new_hash.merge(k => refs_to_swagger(v))
          end
        when Array
          value.map { |v| refs_to_swagger(v) }
        else
          value
        end
      end

      # recursively exclude $comment fields
      def remove_comments(value)
        case value
        when Hash
          value.reduce({}) do |new_hash, (k, v)|
            next new_hash if k == '$comment'

            new_hash.merge(k => remove_comments(v))
          end
        when Array
          value.map { |v| remove_comments(v) }
        else
          value
        end
      end

      private

      def ref?(key, val)
        key == '$ref' && JsonSchemaReferenceString.new(val).valid?
      end
    end

    def initialize(json_schema)
      @json_schema = json_schema.as_json
    end

    def to_swagger
      {
        requestBody: { required: true, content: { 'application/json': { schema: { '$ref': top_ref_to_swagger } } } },
        components: { schemas: json_schema_definitions_to_swagger }
      }.as_json
    end

    private

    attr_reader :json_schema

    def top_ref_to_swagger
      JsonSchemaReferenceString.new(json_schema['$ref']).to_swagger
    end

    def json_schema_definitions_to_swagger
      self.class.remove_comments self.class.refs_to_swagger json_schema['definitions']
    end
  end
end
