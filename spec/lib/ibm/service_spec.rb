# frozen_string_literal: true

require 'rails_helper'
require 'common/file_helpers'
require 'ibm/service'
require 'pdf_utilities/pdf_validator'

RSpec.describe Ibm::Service do
  let(:service) { Ibm::Service.new }
  let(:valid_guid) { '123e4567-e89b-12d3-a456-426614174000' }
  let(:valid_form) { { 'field1' => 'value1', 'field2' => 'value2' }.to_json }
  let(:service_path) { 'https://fake.host/api/v1' }

  before do
    allow(Ibm::Configuration.instance).to receive(:service_path).and_return(service_path)
  end

  describe '#upload_form' do
    context 'with valid parameters' do
      it 'performs a PUT request to the correct URL' do
        stub_request(:put, "#{service_path}/#{valid_guid}")
          .with(
            body: valid_form,
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(status: 200, body: '', headers: {})

        response = service.upload_form(form: valid_form, guid: valid_guid)
        expect(response.status).to eq(200)
      end
    end

    context 'with invalid JSON form' do
      it 'raises JSON::ParserError' do
        invalid_form = '{invalid_json: true'

        expect do
          service.upload_form(form: invalid_form, guid: valid_guid)
        end.to raise_error(JSON::ParserError)
      end
    end

    context 'when the upload fails' do
      it 'logs an error message' do
        stub_request(:put, "#{service_path}/#{valid_guid}")
          .with(
            body: valid_form,
            headers: { 'Content-Type' => 'application/json' }
          )
          .to_return(status: 500, body: 'Internal Server Error', headers: {})

        expect(Rails.logger).to receive(:error).with(
          'IBM MMS Upload Error: the server responded with status 500 - method and url' \
          ' are not available due to include_request: false on Faraday::Response::RaiseError middleware',
          { guid: valid_guid }
        )

        service.upload_form(form: valid_form, guid: valid_guid)
      end
    end
  end

  describe '#upload_url' do
    it 'returns the correct upload URL' do
      expected_url = "#{service_path}/#{valid_guid}"
      expect(service.upload_url(guid: valid_guid)).to eq(expected_url)
    end
  end
end
