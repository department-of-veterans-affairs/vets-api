# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/schema_contract/validator'

describe SchemaContract::Validator do
  describe '#validate' do
    let(:fixture) { 'spec/fixtures/schema_contract/test_schema.json' }
    # let(:data) { JSON.parse(appointment_fixtures, symbolize_names: true) }
    let(:test_data) { Rails.root.join(fixture).read }

    # make a factory
    let(:contract_test) do
      SchemaContractTest.create(name: 'test_index', user_uuid: '1234', response:, status: 'initiated')
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
            kind: nil,
            status: 'groovy',
            start: 'replace with date string',
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
          SchemaContract::Validator.new(contract_test.id).validate
        end.not_to raise_error(SchemaContract::Validator::SchemaContractValidationError)
      end

      it 'does not log errors' do
        expect { SchemaContract::Validator.new(contract_test.id).validate }.to change {
                                                                                 contract_test.reload.status
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
          SchemaContract::Validator.new(contract_test.id).validate
        end.to change { contract_test.reload.status }.from('initiated').to('schema_errors_found')
        expect(contract_test.error_details).to \
          match(%r{^\["The property '#/data/0' did not contain a required property of 'id' in schema #{uuid_regex}"\]$})
      end
    end

    context 'when response contains unpermitted properties' do
      let(:response) do
        matching_response[:data][0][:that_little_guy_over_there] = "Don't worry about that little guy."
        matching_response
      end

      it 'records errors' do
        expect do
          SchemaContract::Validator.new(contract_test.id).validate
        end.to change { contract_test.reload.status }.from('initiated').to('schema_errors_found')

        expect(contract_test.error_details). to eq("[\"The property '#/data/0' contains additional properties [\\\"that_little_guy_over_there\\\"] outside of the schema when none are allowed in schema a406724b-1490-5b39-aecf-23c8dad09921\"]")
        # expect(contract_test.error_details).to \
        # match(/\[\\"The property '#\/data\/0' contains additional properties \[\\\\\\"that_little_guy_over_there\\\\\\"\] outside of the schema when none are allowed in schema #{uuid_regex}\\"\]$/)
      end
    end

    context 'when response contains properties of the wrong type' do
      let(:response) do
        matching_response[:data][0][:id] = 1
        matching_response
      end

      it 'records errors' do
        expect do
          SchemaContract::Validator.new(contract_test.id).validate
        end.to change { contract_test.reload.status }.from('initiated').to('schema_errors_found')

        expect(contract_test.error_details). to eq("[\"The property '#/data/0/id' of type integer did not match the following type: string in schema a406724b-1490-5b39-aecf-23c8dad09921\"]")
      end
    end

    context 'when required nested property is omitted' do

    end



    context 'when schema contract does not exist in db' do
    end

    context 'when schema file does not exist' do
    end

    context 'when schema file is invalid' do
    end
  end
end
