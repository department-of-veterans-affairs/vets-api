# frozen_string_literal: true

require 'rails_helper'
require_relative Rails.root.join('app', 'models', 'schema_contract', 'validator')

describe SchemaContract::Validator, aggregate_failures: true do
  describe '#validate' do
    let(:fixture) { 'spec/fixtures/schema_contract/test_schema.json' }
    let(:test_data) { Rails.root.join(fixture).read }

    # make a factory
    let(:contract_record) do
      SchemaContract::SchemaContractTest.create(name: 'test_index', user_uuid: '1234', response:, status: 'initialized')
    end
    let(:matching_response) do
      {
        data: [
          {
            required_string: '1234',
            required_object: {
              required_nested_object: {
                nested_optional_int: 1
              }
            }
          }
        ],
        meta: [{}]
      }
    end
    let(:uuid_regex) { /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/ }

    context 'when response matches schema' do
      let(:response) { matching_response }

      it 'updates record and does not log errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.not_to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('success')
      end
    end

    describe 'when required properties are missing' do
      let(:response) do
        matching_response[:data][0].delete(:required_string)
        matching_response
      end

      it 'raises and records errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('schema_errors_found')
        expect(contract_record.error_details).to \
          match(%r{^\["The property '#/data/0' did not contain a required property of 'required_string' in schema #{uuid_regex}"\]$})
      end
    end

    context 'when response contains optional permitted properties' do
      let(:response) do
        matching_response[:data][0][:optional_nullable_string] = ':D'
        matching_response
      end

      it 'updates record and does not log errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.not_to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('success')
      end
    end

    context 'when response contains unpermitted properties' do
      let(:response) do
        matching_response[:data][0][:extra] = ':D'
        matching_response
      end

      it 'raises and records errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('schema_errors_found')
        expect(contract_record.error_details).to \
          match(%r{^\["The property '#/data/0' contains additional properties \[\\"extra\\"\] outside of the schema \
when none are allowed in schema #{uuid_regex}"\]$})
      end
    end

    context 'when response contains properties of the wrong type' do
      let(:response) do
        matching_response[:data][0][:required_string] = 1
        matching_response
      end

      it 'raises and records errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('schema_errors_found')

        expect(contract_record.error_details).to \
          match(%r{^\["The property '#/data/0/required_string' of type integer did not match the following type: string in schema #{uuid_regex}"\]$})
      end
    end

    context 'when response contains disallowed null value' do
      let(:response) do
        matching_response[:data][0][:required_string] = nil
        matching_response
      end

      it 'raises and records errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('schema_errors_found')

        expect(contract_record.error_details).to \
          match(%r{^\["The property '#/data/0/required_string' of type null did not match the following type: string in schema #{uuid_regex}"\]$})
      end
    end

    context 'when response contains allowed null value' do
      let(:response) do
        matching_response[:data][0][:optional_nullable_string] = nil
        matching_response
      end

      it 'updates record' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.not_to raise_error(SchemaContract::Validator::SchemaContractValidationError)
      end

      it 'does not log errors' do
        expect { SchemaContract::Validator.new(contract_record.id).validate }.to change {
                                                                                   contract_record.reload.status
                                                                                 }.from('initialized').to('success')
      end
    end

    context 'when required nested property is omitted' do
      let(:response) do
        matching_response[:data][0][:required_object].delete(:required_nested_object)
        matching_response
      end

      it 'raises and records errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('schema_errors_found')

        expect(contract_record.error_details).to \
          match(%r{^\["The property '#/data/0/required_object' did not contain a required property of \
'required_nested_object' in schema #{uuid_regex}"\]$})
      end
    end

    context 'when unpermitted nested property is included' do
      let(:response) do
        matching_response[:data][0][:required_object][:required_nested_object][:extra] = ':D'
        matching_response
      end

      it 'raises and records errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('schema_errors_found')

        expect(contract_record.error_details).to \
          match(%r{^\["The property '#/data/0/required_object/required_nested_object' contains additional properties \
\[\\"extra\\"\] outside of the schema when none are allowed in schema #{uuid_regex}"\]$})
      end
    end

    context 'when schema contract does not exist in db' do
      it 'raises not found' do
        expect do
          SchemaContract::Validator.new('1').validate
        end.to raise_error(ActiveRecord::RecordNotFound, "Couldn't find SchemaContract::SchemaContractTest with 'id'=1")
      end
    end

    context 'when schema file does not exist' do
      let(:contract_record) do
        SchemaContract::SchemaContractTest.create(name: 'not_real', user_uuid: '1234', response: matching_response,
                                                  status: 'initialized')
      end

      it 'raises error' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError, 'No schema file not_real found.')
        expect(contract_record.reload.status).to eq('schema_not_found')
      end
    end

    context 'when schema file is invalid' do
    end
  end
end
