# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../lib/schema_contract/validator'

describe SchemaContract::Validator do
  describe '#validate' do
    let(:fixture) { 'spec/fixtures/schema_contract/test_schema.json' }
    # let(:data) { JSON.parse(appointment_fixtures, symbolize_names: true) }
    let(:test_data) { File.read(Rails.root.join(fixture)) }

    # make a factory
    let(:contract_test) { SchemaContractTest.create(name: 'test_index', user_uuid: '1234', response:, status: 'initiated') }

    context 'when response matches schema' do
      let(:response) do
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

      it 'updates record' do
        expect { SchemaContract::Validator.new(contract_test.id).validate }.not_to raise_error(SchemaContract::Validator::SchemaContractValidationError)
      end

      it 'does not log errors' do
        expect { SchemaContract::Validator.new(contract_test.id).validate }.to change { contract_test.reload.status }.from('initiated').to('success')
      end
    end

    describe 'when response does not match schema' do
      # test various error types
    end

    context 'when schema contract does not exist in db' do

    end

    context 'when schema file does not exist' do

    end

    context 'when schema file is invalid' do

    end
  end
end