# coding: utf-8
# frozen_string_literal: true

module AppealsApi
  module V1
    class HigherLevelReviewsControllerSwagger
      include Swagger::Blocks

      read_file = lambda do |path|
        File.read(AppealsApi::Engine.root.join(*path))
      end

      read_json = lambda do |path|
        JSON.parse(read_file.call(path))
      end

      read_json_from_same_dir = lambda do |filename|
        read_json.call(['app', 'swagger', 'appeals_api', 'v1', filename])
      end

      hlr_tags = ['Higher-Level Reviews']
      hlr_show_success = read_json_from_same_dir['response_hlr_show_success.json']
      hlr_show_not_found = read_json_from_same_dir['response_hlr_show_not_found.json']
      hlr_create_error = read_json_from_same_dir['response_hlr_create_error.json']

      headers_json_schema = read_json[['config', 'schemas', '200996_headers.json']].deep_merge(
        read_json_from_same_dir['swagger_fields_to_add_to_200996_headers_json_schema.json']
      )
      hlr_create_parameters = %w[
        Ssn
        First-Name
        Middle-Initial
        Last-Name
        Birth-Date
        File-Number
        Service-Number
        Insurance-Policy-Number
      ].map do |key|
        header_key = "X-VA-#{key == 'Ssn' ? 'SSN' : key}"
        definition_name = "#{key[0].downcase}#{key[1..]&.gsub('-', '')}"
        schema_name = "HlrCreateParameter#{definition_name[0].upcase}#{definition_name[1..]}"
        {
          name: header_key,
          'in': 'header',
          description: headers_json_schema['definitions'][definition_name]['description'],
          required: headers_json_schema['required'].include?(header_key),
          schema: { '$ref': "#/components/schemas/#{schema_name}" }
        }
      end

      hlr_create_json_schema_unparsed = read_file[['config', 'schemas', '200996.json']]
      hlr_create_request_body = AppealsApi::JsonSchemaToSwaggerConverter.new(
        JSON.parse(hlr_create_json_schema_unparsed),
        prefix: 'HlrCreate'
      ).to_swagger['requestBody']
      hlr_create_request_body['content']['application/json']['examples'] = {
        'all fields used': { value: read_json[['spec', 'fixtures', 'valid_200996.json']] },
        'minimum fields used': { value: read_json[['spec', 'fixtures', 'valid_200996_minimum.json']] }
      }

      swagger_path '/higher_level_reviews' do
        operation :post do
          key :summary, 'Create a Higher-Level Review'
          key(
            :description,
            <<~DESC
              Submits a Decision Review request of type *Higher-Level Review*.
              This endpoint is analogous to submitting
              [VA Form 20-0996](https://www.vba.va.gov/pubs/forms/VBA-20-0996-ARE.pdf)
              via mail or fax.
            DESC
          )
          key :tags, hlr_tags
          key :parameters, hlr_create_parameters
          key :requestBody, hlr_create_request_body
          key :responses, { '200': hlr_show_success, '422': hlr_create_error }
        end
      end

      swagger_path '/higher_level_reviews/{uuid}' do
        operation :get do
          key :summary, 'Show a Higher-Level Review'
          key :description, 'Returns all of the data associated with a specific Higher-Level Review'
          key :tags, hlr_tags
          parameter do
            key :name, 'uuid'
            key :in, 'path'
            key :required, true
            key :description, 'Higher-Level Review UUID'
            schema { key :'$ref', :Uuid }
          end
          key :responses, { '200': hlr_show_success, '404': hlr_show_not_found }
        end
      end

      swagger_path '/higher_level_reviews/schema' do
        operation :get do
          key :summary, 'Return the JSON Schema for POST /higher_level_reviews'
          key(
            :description,
            'Return the [JSON Schema](https://json-schema.org/) for the `POST /higher_level_reviews` enpdoint.'
          )
          key :tags, hlr_tags
          response '200' do
            key :description, 'the JSON Schema for POST /higher_level_reviews'
            key(
              :content,
              {
                'application/json': {
                  examples: {
                    default: {
                      value: hlr_create_json_schema_unparsed
                    }
                  }
                }
              }
            )
          end
        end
      end

      swagger_path '/higher_level_reviews/validate' do
        operation :post do
          key :summary, 'Validate a POST /higher_level_reviews request body (dry run)'
          key(
            :description,
            'Validate a `POST /higher_level_reviews` request body against the JSON Schema. ' \
            'Like the `POST /higher_level_reviews`, but *only* does the validations **—does not submit anything.**'
          )
          key :tags, hlr_tags
          key :parameters, hlr_create_parameters
          key :requestBody, hlr_create_request_body
          key(
            :responses,
            {
              "200": {
                "description": 'Valid',
                "content": {
                  "application/json": {
                    "schema": {
                      "type": 'object',
                      "properties": {
                        "data": {
                          "type": 'object',
                          "properties": {
                            "type": {
                              "type": 'string',
                              "enum": ['appeals_api_higher_level_review_validation']
                            },
                            "attributes": {
                              "type": 'object',
                              "properties": {
                                "status": {
                                  "type": 'string',
                                  "enum": ['valid']
                                }
                              }
                            }
                          }
                        }
                      }
                    },
                    "examples": {
                      "valid": {
                        "value": {
                          "data": {
                            "type": 'appeals_api_higher_level_review_validation',
                            "attributes": {
                              "status": 'valid'
                            }
                          }
                        }
                      }
                    }
                  }
                }
              },
              '422': hlr_create_error
            }
          )
        end
      end
    end
  end
end
