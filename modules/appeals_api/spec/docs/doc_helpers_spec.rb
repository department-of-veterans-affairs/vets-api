# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/doc_helpers'

describe DocHelpers do
  subject { Object.new.extend(DocHelpers) }

  let(:schema_path) { AppealsApi::Engine.root.join('spec', 'fixtures', 'example_json_schema.json') }
  let(:schema) { JSON.parse(File.read(schema_path)) }
  let(:icn_field_schema) do
    JSON.parse(
      File.read(AppealsApi::Engine.root.join('config', 'schemas', 'shared', 'v0', 'icn.json'))
    ).dig('properties', 'icn')
  end

  describe '#_resolve_value_schema' do
    let(:value_keys) { %w[] }
    let(:result) { subject._resolve_value_schema(schema, *value_keys) }

    describe 'plain value' do
      let(:value_keys) { %w[properties exampleDateValue] }

      it { expect(result).to eq(schema.dig(*value_keys)) }
    end

    describe 'property that references a definition' do
      let(:value_keys) { %w[properties exampleDefinitionValue1] }

      it { expect(result).to eq(schema.dig('definitions', 'exampleDefinitionValue')) }
    end

    describe 'property that references a definition, with extra attributes' do
      let(:value_keys) { %w[properties exampleDefinitionValue2] }

      it 'merges the extra attributes into the referenced value' do
        expect(result['description']).to match(/definition reference field/)
        expect(result['type']).to eq('string')
      end
    end

    describe 'property that references a shared schema' do
      let(:value_keys) { %w[properties exampleSharedSchemaValue1] }

      it { expect(result).to eq(icn_field_schema) }
    end

    describe 'property that references a shared_schema, with extra attributes' do
      let(:value_keys) { %w[properties exampleSharedSchemaValue2] }

      it 'merges the extra attributes into the shared schema' do
        expect(result).to match(hash_including(icn_field_schema.except('description')))
        expect(result['description']).to match(/shared schema field/)
      end
    end
  end

  describe '#parameter_from_schema' do
    let(:value_keys) { %w[] }
    let(:result) { subject.parameter_from_schema(schema_path, *value_keys) }

    describe 'plain value' do
      let(:value_keys) { %w[properties exampleDateValue] }
      let(:expected) do
        {
          name: 'exampleDateValue',
          description: 'Description of example date field',
          example: '2001-01-01',
          required: true,
          schema: {
            type: 'string',
            format: 'date'
          }
        }
      end

      it { expect(result).to eq(expected) }
    end

    describe 'property that references a definition' do
      let(:value_keys) { %w[properties exampleDefinitionValue1] }
      let(:expected) do
        {
          name: 'exampleDefinitionValue1',
          description: 'Description of example definition field',
          required: true,
          schema: {
            type: 'string'
          }
        }
      end

      it { expect(result).to eq(expected) }
    end

    describe 'property that references a definition, with extra attributes' do
      let(:value_keys) { %w[properties exampleDefinitionValue2] }
      let(:expected) do
        {
          name: 'exampleDefinitionValue2',
          description: 'Description of example definition reference field',
          schema: {
            type: 'string'
          }
        }
      end

      it { expect(result).to eq(expected) }
    end

    describe 'property that references a shared schema' do
      let(:value_keys) { %w[properties exampleSharedSchemaValue1] }
      let(:expected) do
        {
          name: 'exampleSharedSchemaValue1',
          description: "Veteran's Master Person Index (MPI) Integration Control Number (ICN)",
          example: '1234567890V123456',
          schema: {
            type: 'string',
            pattern: '^[0-9]{10}V[0-9]{6}$',
            minLength: 17,
            maxLength: 17
          }
        }
      end

      it { expect(result).to eq(expected) }
    end

    describe 'property that references a shared_schema, with extra attributes' do
      let(:value_keys) { %w[properties exampleSharedSchemaValue2] }
      let(:expected) do
        {
          name: 'exampleSharedSchemaValue2',
          description: 'Description of example shared schema field',
          example: '1234567890V123456',
          required: true,
          schema: {
            type: 'string',
            pattern: '^[0-9]{10}V[0-9]{6}$',
            minLength: 17,
            maxLength: 17
          }
        }
      end

      it { expect(result).to eq(expected) }
    end
  end
end
