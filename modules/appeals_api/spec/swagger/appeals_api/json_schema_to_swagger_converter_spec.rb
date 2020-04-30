# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'json_schema_to_swagger_converter.rb')

describe AppealsApi::JsonSchemaToSwaggerConverter do
  let(:json_schema) do
    {
      "$schema": 'http://json-schema.org/draft-07/schema#',
      "description": 'Example JSON Schema',
      "type": 'object',
      "properties": {
        "aardvark": { "$ref": '#/definitions/cat' },
        "bat": { "$ref": '#/definitions/dog' }
      },
      "additionalProperties": false,
      "required": %w[aardvark bat],
      "definitions": {
        "cat": {
          "$comment": 'feline',
          "type": 'object',
          "properties": {
            "elephant": { "type": 'string' },
            "fox": { "type": 'string' }
          },
          "additionalProperties": false,
          "required": ['fox']
        },
        "dog": {
          "type": 'object',
          "properties": {
            "giraffe": { "type": 'string' },
            "hippo": { "$ref": '#/definitions/hippo' }
          },
          "additionalProperties": false,
          "required": ['giraffe']
        },
        "hippo": {
          "type": 'object',
          "properties": {
            "ibex": { "type": 'string' }
          },
          "additionalProperties": true
        }
      }
    }.as_json
  end

  let(:swagger) do
    {
      "requestBody": {
        "required": true,
        "content": {
          "application/json": {
            "schema": {
              "type": 'object',
              "properties": {
                "aardvark": {
                  "$ref": '#/components/schemas/HelloCat'
                },
                "bat": {
                  "$ref": '#/components/schemas/HelloDog'
                }
              },
              "additionalProperties": false,
              "required": %w[aardvark bat]
            }
          }
        }
      },
      "components": {
        "schemas": {
          "HelloCat": {
            "type": 'object',
            "properties": {
              "elephant": {
                "type": 'string'
              },
              "fox": {
                "type": 'string'
              }
            },
            "additionalProperties": false,
            "required": [
              'fox'
            ]
          },
          "HelloDog": {
            "type": 'object',
            "properties": {
              "giraffe": {
                "type": 'string'
              },
              "hippo": {
                "$ref": '#/components/schemas/HelloHippo'
              }
            },
            "additionalProperties": false,
            "required": [
              'giraffe'
            ]
          },
          "HelloHippo": {
            "type": 'object',
            "properties": {
              "ibex": {
                "type": 'string'
              }
            },
            "additionalProperties": true
          }
        }
      }
    }.as_json
  end

  describe '#to_swagger' do
    subject { described_class.new(json_schema, prefix: 'Hello').to_swagger }

    it 'converts references from JSON-Schema-style to swagger-style (and pretty much nothing else)' do
      expect(subject).to eq(swagger)
    end
  end
end
