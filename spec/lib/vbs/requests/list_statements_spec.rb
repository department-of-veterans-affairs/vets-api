# frozen_string_literal: true

require 'rails_helper'
require 'vbs/requests/list_statements'
require_relative './vbs_request_model_shared_example'

describe VBS::Requests::ListStatements do
  it_behaves_like 'a VBS request model'

  describe '::HTTP_METHOD' do
    it 'is :post' do
      expect(described_class::HTTP_METHOD).to eq(:post)
    end
  end

  describe '::PATH' do
    it 'is :post' do
      expect(described_class::PATH).to eq('/GetStatementsByEDIPIAndVistaAccountNumber')
    end
  end

  describe '::schema' do
    it 'defines an object' do
      expect(described_class.schema['type']).to eq('object')
    end

    it 'does not allow additional properties' do
      expect(described_class.schema['additionalProperties']).to be(false)
    end

    it 'requires "edipi" and "vistaAccountNumbers"' do
      expect(described_class.schema['required']).to eq(%w[edipi vistaAccountNumbers])
    end

    describe 'properties' do
      it 'defines "edipi"' do
        expect(described_class.schema['properties']['edipi']['type']).to eq('string')
      end

      it 'defines "vistaAccountNumbers"' do
        expect(described_class.schema['properties']['vistaAccountNumbers']['type']).to eq('array')
        expect(described_class.schema['properties']['vistaAccountNumbers']['items']).to eq(
          {
            'type' => 'string',
            'minLength' => 16,
            'maxLength' => 16
          }
        )
      end
    end
  end
end
