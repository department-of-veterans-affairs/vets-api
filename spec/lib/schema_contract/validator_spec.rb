# frozen_string_literal: true

require 'rails_helper'
require 'lib/schema_contract/validator'

describe SchemaContract::Validator do
  describe '#validate' do
    let(:fixture) { 'spec/fixtures/schema_contract/test.json' }
    # let(:data) { JSON.parse(appointment_fixtures, symbolize_names: true) }
    let(:test_data) { File.read(Rails.root.join(fixture)) }

    # make a factory
    let(:contact_test) { SchemaContractTest.create(name: 'test', user_uuid: '1234', response: test_data, status: 'initiated' ) }

    context 'when response matches schema' do
      it 'updates record' do

      end

      it 'does not log errors' do

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