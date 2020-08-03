# frozen_string_literal: true

module AppealsApi::V1::SwaggerRoot
  include Swagger::Blocks

  read_file = ->(path) { File.read(AppealsApi::Engine.root.join(*path)) }
  read_file_from_same_dir = ->(filename) { read_file.call(['app', 'swagger', 'appeals_api', 'v1', filename]) }
  read_json_schema = ->(filename) { JSON.parse read_file[['config', 'schemas', filename]] }

  # rubocop:disable Metrics/BlockLength
  swagger_root do
    key :openapi, '3.0.0'
    info do
      key :title, 'Decision Reviews'
      key :version, '1.0.0'
      key :description, read_file_from_same_dir['api_description.md']
      key :termsOfService, 'https://developer.va.gov/terms-of-service'
      contact do
        key :name, 'VA API Benefits Team'
      end
    end

    url = ->(prefix = '') { "https://#{prefix}api.va.gov/services/appeals/{version}/decision_reviews" }

    server description: 'VA.gov API sandbox environment', url: url['sandbox-'] do
      variable(:version) { key :default, 'v1' }
    end

    server description: 'VA.gov API production environment', url: url[''] do
      variable(:version) { key :default, 'v1' }
    end

    key :basePath, '/services/appeals/v1'
    key :consumes, ['application/json']
    key :produces, ['application/json']

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
      hlrStatus: {
        type: :string, enum: %w[pending submitting submitted processing error uploaded received success vbms expired]
      },
      errorWithTitleAndDetail: {
        type: :array,
        items: { type: :object, properties: { title: { type: :string }, detail: { type: :string } } }
      }
    }.merge(hlr_create_header_schemas).merge(hlr_create_schemas).merge(non_blank_string)

    security_scheme = {
      apikey: {
        type: :apiKey,
        name: :apikey,
        in: :header
      }
    }

    key :components, { schemas: schemas, securitySchemes: security_scheme }
  end
  # rubocop:enable Metrics/BlockLength
end
