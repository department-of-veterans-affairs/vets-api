# frozen_string_literal: true

class AppealsApi::V1::NodJsonSchemaSwaggerHelper
  def params
    headers_swagger = AppealsApi::JsonSchemaToSwaggerConverter.new(headers_json_schema).to_swagger
    header_schemas = headers_swagger['components']['schemas']
    headers = header_schemas['nodCreateHeadersRoot']['properties'].keys
    headers.map do |header|
      {
        name: header,
        in: 'header',
        description: header_schemas[header]['allOf'][0]['description'],
        required: header_schemas['nodCreateHeadersRoot']['required'].include?(header),
        schema: { '$ref': "#/components/schemas/#{header}" }
      }
    end
  end

  def request_body
    nod_create_request_body = AppealsApi::JsonSchemaToSwaggerConverter.new(
      nod_create_json_schema
    ).to_swagger['requestBody']

    nod_create_request_body['content']['application/json']['examples'] = {
      'minimum fields used': { value: example_min_fields_used },
      'all fields used': { value: example_all_fields_used }
    }

    nod_create_request_body
  end

  def responses
    {
      '200': response_show_success,
      '404': response_show_not_found,
      '422': response_create_error_422,
      '500': response_create_error_500
    }
  end

  private

  def read_file(path)
    File.read(AppealsApi::Engine.root.join(*path))
  end

  def read_json(path)
    JSON.parse(read_file(path))
  end

  def read_json_from_same_dir(filename)
    read_json(['app', 'swagger', 'appeals_api', 'v1', filename])
  end

  def headers_json_schema
    @headers_json_schema ||= read_json(['config', 'schemas', 'v1', '10182_headers.json'])
  end

  def nod_create_json_schema
    @nod_create_json_schema ||= read_json(['config', 'schemas', 'v1', '10182.json'])
  end

  def example_min_fields_used
    @example_min_fields_used ||= read_json(['spec', 'fixtures', 'v1', 'valid_10182_minimum.json'])
  end

  def example_all_fields_used
    @example_all_fields_used ||= read_json(['spec', 'fixtures', 'v1', 'valid_10182.json'])
  end

  # rubocop:disable Metrics/MethodLength
  def response_show_success
    @response_show_success ||= lambda do
      properties = {
        status: { '$ref': '#/components/schemas/nodStatus' },
        updatedAt: { '$ref': '#/components/schemas/timeStamp' },
        createdAt: { '$ref': '#/components/schemas/timeStamp' },
        formData: { '$ref': '#/components/schemas/nodCreateRoot' }
      }
      type = :noticeOfDisagreement
      schema = {
        type: :object,
        properties: {
          id: { '$ref': '#/components/schemas/uuid' },
          type: { type: :string, enum: [type] },
          attributes: { type: :object, properties: }
        }
      }
      time = '2020-04-23T21:06:12.531Z'
      attrs = { status: :processing, updatedAt: time, createdAt: time, formData: example_all_fields_used }
      example = { data: { id: '1234567a-89b0-123c-d456-789e01234f56', type:, attributes: attrs } }

      {
        description: 'Info about a single Notice of Disagreement',
        content: { 'application/json': { schema:, examples: { nodFound: { value: example } } } }
      }
    end.call
  end
  # rubocop:enable Metrics/MethodLength

  def response_show_not_found
    @response_show_not_found ||= read_json_from_same_dir('response_nod_show_not_found.json')
  end

  def response_create_error_422
    @response_create_error_422 ||= read_json_from_same_dir('response_nod_create_error_422.json')
  end

  def response_create_error_500
    @response_create_error_500 ||= read_json_from_same_dir('response_nod_create_error_500.json')
  end
end
