# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('app', 'swagger', 'appeals_api', 'json_schema_to_swagger_converter.rb')

describe AppealsApi::JsonSchemaToSwaggerConverter do
  describe '#to_swagger' do
    let(:json_schema) do
      {
        '$schema': 'http://json-schema.org/draft-07/schema#',
        description: 'Example JSON Schema',
        '$ref': '#/definitions/root',
        definitions: {
          root: {
            type: 'object',
            properties: {
              aardvark: { "$ref": '#/definitions/cat' },
              bat: { "$ref": '#/definitions/dog' }
            },
            additionalProperties: false,
            required: %w[aardvark bat]
          },
          cat: {
            '$comment': 'feline',
            type: 'object',
            properties: {
              elephant: { type: 'string' },
              fox: { type: 'string' }
            },
            additionalProperties: false,
            required: ['fox']
          },
          dog: {
            type: 'object',
            properties: {
              giraffe: { type: 'string' },
              hippo: { '$ref': '#/definitions/hippo' }
            },
            additionalProperties: false,
            required: ['giraffe']
          },
          hippo: {
            type: 'object',
            properties: {
              ibex: { type: 'string' }
            },
            additionalProperties: true
          }
        }
      }
    end

    let(:swagger) do
      {
        requestBody: {
          required: true,
          content: {
            'application/json': {
              schema: { '$ref': '#/components/schemas/root' }
            }
          }
        },
        components: {
          schemas: {
            root: {
              type: 'object',
              properties: {
                aardvark: { '$ref': '#/components/schemas/cat' },
                bat: { '$ref': '#/components/schemas/dog' }
              },
              additionalProperties: false,
              required: %w[aardvark bat]
            },
            cat: {
              type: 'object',
              properties: {
                elephant: { type: 'string' },
                fox: { type: 'string' }
              },
              additionalProperties: false,
              required: ['fox']
            },
            dog: {
              type: 'object',
              properties: {
                giraffe: { type: 'string' },
                hippo: { '$ref': '#/components/schemas/hippo' }
              },
              additionalProperties: false,
              required: ['giraffe']
            },
            hippo: {
              type: 'object',
              properties: {
                ibex: { type: 'string' }
              },
              additionalProperties: true
            }
          }
        }
      }.as_json
    end

    it 'converts references from JSON-Schema-style to swagger-style (and pretty much nothing else)' do
      expect(described_class.new(json_schema).to_swagger).to eq(swagger)
    end
  end

  describe '.fix_refs_and_remove_comments' do
    let(:input) do
      {
        a: 1,
        '$ref': '#/definitions',
        '$comment': { '$ref': '#/definitions/hippo' },
        b: [
          'cat',
          { '$ref': '#/definitions/dog' },
          [[[{ c: { d: { '$comment': 'Hi', '$ref': '#/definitions/' } } }]]]
        ]
      }.as_json
    end

    let(:output) do
      {
        a: 1,
        '$ref': '#/components/schemas',
        b: [
          'cat',
          { '$ref': '#/components/schemas/dog' },
          [[[{ c: { d: { '$ref': '#/components/schemas/' } } }]]]
        ]
      }.as_json
    end

    it 'swaggerizes references and removes comments' do
      expect(described_class.fix_refs_and_remove_comments(input)).to eq output
    end
  end
end
