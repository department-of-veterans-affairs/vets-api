# frozen_string_literal: true

module AppealsApi::V1::SwaggerRoot
  include Swagger::Blocks

  swagger_root do
    read_json_schema = lambda do |filename|
      JSON.parse(File.read(AppealsApi::Engine.root.join('config', 'schemas', filename)))
    end

    key :openapi, '3.0.0'
    info do
      key :version, '1.0.0'
      key :title, 'Decision Reviews'
      key :description, AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'v1', 'api_description.md')
    end
    server do
      key :url, 'https://sandbox-api.va.gov/services/appeals/{version}/decision_review'
      key :description, 'VA.gov API sandbox environment'
      variable(:version) { key :default, 'v1' }
    end

    hlr_create_schemas = AppealsApi::JsonSchemaToSwaggerConverter.new(
      read_json_schema['200996.json']
    ).to_swagger['components']['schemas']

    hlr_create_header_schemas = AppealsApi::JsonSchemaToSwaggerConverter.new(
      read_json_schema['200996_headers.json']
    ).to_swagger['components']['schemas']

    non_blank_string = { nonBlankString: { type: :string, pattern: '\\S' } }.as_json

    schemas = {
      uuid: { type: :string, pattern: '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' },
      timeStamp: { type: :string, pattern: '\d{4}(-\d{2}){2}T\d{2}(:\d{2}){2}\.\d{3}Z' },
      hlrStatus: { type: :string, enum: AppealsApi::HigherLevelReview.statuses.keys },
      errorWithTitleAndDetail: {
        type: :array,
        items: {
          type: :object,
          properties: {
            title: { type: :string },
            detail: { type: :string }
          }
        }
      }
    }.merge(hlr_create_header_schemas).merge(hlr_create_schemas).merge(non_blank_string)

    key :components, schemas: schemas
  end
end
