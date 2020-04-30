# frozen_string_literal: true

module AppealsApi::V1::SwaggerRoot
  include Swagger::Blocks

  swagger_root do
    read_file = lambda do |path|
      File.read(AppealsApi::Engine.root.join(*path))
    end

    read_json = lambda do |path|
      JSON.parse(read_file.call(path))
    end

    read_json_from_same_dir = lambda do |filename|
      read_json.call(['app', 'swagger', 'appeals_api', 'v1', filename])
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

    json_schema = read_json[['config', 'schemas', '200996.json']].deep_merge(
      read_json_from_same_dir['swagger_fields_to_add_to_200996_json_schema.json']
    )
    headers_json_schema = read_json[['config', 'schemas', '200996_headers.json']].deep_merge(
      read_json_from_same_dir['swagger_fields_to_add_to_200996_headers_json_schema.json']
    )

    key(
      :components,
      {
        schemas: (
          AppealsApi::JsonSchemaToSwaggerConverter.new(
            json_schema, prefix: 'HlrCreate'
          ).to_swagger['components']['schemas']
        ).merge(
          AppealsApi::JsonSchemaToSwaggerConverter.new(
            headers_json_schema, prefix: 'HlrCreateParameter'
          ).to_swagger['components']['schemas']
        ).merge(
          {
            Uuid: { type: :string, pattern: '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' },
            TimeStamp: { type: :string, pattern: '\d{4}(-\d{2}){2}T\d{2}(:\d{2}){2}\.\d{3}Z' },
            HlrStatus: { type: :string, enum: AppealsApi::HigherLevelReview.statuses.keys },
            ErrorWithTitleAndDetail: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  title: { type: :string },
                  detail: { type: :string }
                }
              }
            }
          }
        )
      }
    )
  end
end
