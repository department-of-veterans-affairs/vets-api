# frozen_string_literal: true

require 'rails_helper'
require 'vets/response'

RSpec.describe Vets::Response, type: :model do
  let(:response_body) { { 'message' => 'Success', 'data' => { 'id' => 1 } } }
  let(:status_code) { 200 }
  let(:schema_name) { 'example_schema' }
  let(:response_object) { OpenStruct.new(body: response_body, status: status_code) }

  describe '#initialize' do
    it 'parses the JSON body when passed as a string' do
      json_body = response_body.to_json
      response = described_class.new(status_code:, body: json_body)

      expect(response.body).to eq(response_body)
    end

    it 'sets the status_code as an integer' do
      response = described_class.new(status_code: '200', body: response_body)

      expect(response.status_code).to eq(200)
    end

    it 'validates the body schema if schema_name is provided' do
      schema_path = Rails.root.join('lib', 'apps', 'schemas', "#{schema_name}.json").to_s

      expect(JSON::Validator).to receive(:validate!).with(schema_path, response_body, strict: false)

      described_class.new(status_code:, body: response_body, schema_name:)
    end

    context 'when schema is not valid' do
      it 'returns an error' do
        expect do
          described_class.new(status_code:, body: response_body, schema_name: 'apps')
        end.to raise_error(JSON::Schema::ValidationError)
      end
    end
  end

  describe '#ok?' do
    it 'returns true if the status code is 200' do
      response = described_class.new(status_code: 200, body: response_body)

      expect(response.ok?).to be true
    end

    it 'returns false for other status codes' do
      response = described_class.new(status_code: 404, body: response_body)

      expect(response.ok?).to be false
    end
  end

  describe '#accepted?' do
    it 'returns true if the status code is 202' do
      response = described_class.new(status_code: 202, body: response_body)

      expect(response.accepted?).to be true
    end

    it 'returns false for other status codes' do
      response = described_class.new(status_code: 200, body: response_body)

      expect(response.accepted?).to be false
    end
  end

  describe '#cache?' do
    it 'returns true if the response is ok?' do
      response = described_class.new(status_code: 200, body: response_body)

      expect(response.cache?).to be true
    end

    it 'returns false if the response is not ok?' do
      response = described_class.new(status_code: 404, body: response_body)

      expect(response.cache?).to be false
    end
  end

  describe '#metadata' do
    it 'returns a hash with the status text for known status codes' do
      response = described_class.new(status_code: 200, body: response_body)

      expect(response.metadata).to eq({ status: 'OK' })
    end

    it 'returns SERVER_ERROR for unknown status codes' do
      response = described_class.new(status_code: 500, body: response_body)

      expect(response.metadata).to eq({ status: 'SERVER_ERROR' })
    end
  end

  describe '.build_from_response' do
    let(:mock_response) { double('response', status: 200, body: response_body.to_json) }

    context 'when response is a Faraday response object' do
      it 'builds a Vets::Response instance from a response object' do
        response = described_class.build_from_response(mock_response)

        expect(response).to be_a(Vets::Response)
        expect(response.status_code).to eq(200)
        expect(response.body).to eq(response_body)
      end
    end

    context 'when response is a Hash' do
      it 'builds a Vets::Response instance from a hash' do
        response_hash = { status: 200, body: response_body.to_json }
        response = described_class.build_from_response(response_hash)

        expect(response.status_code).to eq(200)
        expect(response.body).to eq(response_body)
      end
    end

    it 'passes the schema_name to the initializer' do
      allow(JSON::Validator).to receive(:validate!).and_return(true)
      allow(described_class).to receive(:new).and_call_original
      described_class.build_from_response(mock_response, schema_name: 'test_schema')

      expect(described_class).to have_received(:new).with(
        status_code: 200, body: response_body.to_json, schema_name: 'test_schema'
      )
    end
  end
end
