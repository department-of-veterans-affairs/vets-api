# frozen_string_literal: true

module AppealsApi::V2
  module Schemas
    class HigherLevelReviews
      include Swagger::Blocks

      swagger_component do
        schema :uuid do
          key :type, :string
          key :pattern, '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$'
        end

        schema :timeStamp do
          key :type, :string
          key :pattern, '\d{4}(-\d{2}){2}T\d{2}(:\d{2}){2}\.\d{3}Z'
        end

        schema :errorWithTitleAndDetail do
          key :type, :array

          items do
            key :type, :object

            property :title do
              key :type, :string
            end

            property :detail do
              key :type, :string
            end
          end
        end
      end

      def self.hlr_legacy_schemas
        read_file = ->(path) { File.read(AppealsApi::Engine.root.join(*path)) }

        read_json_schema = ->(filename) { JSON.parse read_file[['config', 'schemas', 'v2', filename]] }

        hlr_create_schemas = AppealsApi::JsonSchemaToSwaggerConverter.new(
          read_json_schema['200996.json']
        ).to_swagger['components']['schemas']

        hlr_create_header_schemas = AppealsApi::JsonSchemaToSwaggerConverter.new(
          read_json_schema['200996_headers.json']
        ).to_swagger['components']['schemas']

        # These schema definitions were originally overwriting all schemas on
        # the Swagger::Blocks::Nodes::RootNode, which disallowed for any further
        # schema definitions. I opted to merge these back in after the fact,
        # rather than parse out the JSON schemas into swagger-blocks DSL.

        {
          components: {
            schemas: hlr_create_schemas.merge(hlr_create_header_schemas)
          }
        }
      end
    end
  end
end
