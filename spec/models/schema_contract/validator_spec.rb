# frozen_string_literal: true

require 'rails_helper'
require_relative Rails.root.join('app/models/schema_contract/validator')

describe SchemaContract::Validator do
  describe '#validate' do
    let(:fixture) { 'spec/fixtures/schema_contract/test_schema.json' }
    let(:test_data) { Rails.root.join(fixture).read }

    # make a factory
    let(:contract_record) do
      SchemaContract::SchemaContractTest.create(name: 'test_index', user_uuid: '1234', response:, status: 'initiated')
    end
    let(:matching_response) do
      {
        data: [
          {
            id: '1234',
            identifier: [{
              system: 'VA',
              value: 'medicine'
            }],
            extension: {
              cc_location: {
                address: {
                  street: '1 Main St.',
                  city: 'NYC',
                  state: 'NY',
                  zip: '00001'
                }
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

      it 'updates record' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.not_to raise_error(SchemaContract::Validator::SchemaContractValidationError)
      end

      it 'does not log errors' do
        expect { SchemaContract::Validator.new(contract_record.id).validate }.to change {
                                                                                   contract_record.reload.status
                                                                                 }.from('initiated').to('success')
      end
    end

    describe 'when required properties are missing' do
      let(:response) do
        matching_response[:data][0].delete(:id)
        matching_response
      end

      it 'records errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('schema_errors_found')
        expect(contract_record.error_details).to \
          match(%r{^\["The property '#/data/0' did not contain a required property of 'id' in schema #{uuid_regex}"\]$})
      end
    end

    context 'when response contains unpermitted properties' do
      let(:response) do
        matching_response[:data][0][:extra] = ':D'
        matching_response
      end

      it 'records errors' do
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
        matching_response[:data][0][:id] = 1
        matching_response
      end

      it 'records errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('schema_errors_found')

        expect(contract_record.error_details).to \
          match(%r{^\["The property '#/data/0/id' of type integer did not match the following type: string in schema #{uuid_regex}"\]$})
      end
    end

    context 'when response contains disallowed null value' do
      let(:response) do
        matching_response[:data][0][:id] = nil
        matching_response
      end

      it 'records errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('schema_errors_found')

        expect(contract_record.error_details).to \
          match(%r{^\["The property '#/data/0/id' of type null did not match the following type: string in schema #{uuid_regex}"\]$})
      end
    end

    context 'when required nested property is omitted' do
      let(:response) do
        matching_response[:data][0][:extension].delete(:cc_location)
        matching_response
      end

      it 'records errors' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError)
        expect(contract_record.reload.status).to eq('schema_errors_found')

        expect(contract_record.error_details).to \
          match(%r{^\["The property '#/data/0/extension' did not contain a required property of 'cc_location' in schema #{uuid_regex}"\]$})
      end
    end

    context 'when unpermitted nested property is included' do
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
        SchemaContract::SchemaContractTest.create(name: 'not_real', user_uuid: '1234', response: matching_response, status: 'initiated')
      end

      it 'raises error' do
        expect do
          SchemaContract::Validator.new(contract_record.id).validate
        end.to raise_error(SchemaContract::Validator::SchemaContractValidationError, 'No schema file not_real found.')
      end
    end

    context 'when schema file is invalid' do
    end
  end
end
