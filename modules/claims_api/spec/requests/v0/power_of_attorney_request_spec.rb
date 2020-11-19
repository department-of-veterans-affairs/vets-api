# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Power of Attorney ', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-VA-EDIPI': '1007697216',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-User': 'adhoc.test.user',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M',
      'X-VA-LOA': '3' }
  end

  describe '#2122' do
    let(:data) { File.read(Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'form_2122_json_api.json')) }
    let(:path) { '/services/claims/v0/forms/2122' }
    let(:schema) { File.read(Rails.root.join('modules', 'claims_api', 'config', 'schemas', '2122.json')) }

    it 'returns a successful get response with json schema' do
      get path, headers: headers
      json_schema = JSON.parse(response.body)['data'][0]
      expect(json_schema).to eq(JSON.parse(schema))
    end

    it 'returns a successful response with all the data' do
      post path, params: data, headers: headers
      parsed = JSON.parse(response.body)
      expect(parsed['data']['type']).to eq('claims_api_power_of_attorneys')
      expect(parsed['data']['attributes']['status']).to eq('pending')
    end

    it 'returns the same successful response with all the data' do
      post path, params: data, headers: headers
      parsed = JSON.parse(response.body)
      expect(parsed['data']['type']).to eq('claims_api_power_of_attorneys')
      post path, params: data, headers: headers
      newly_parsed = JSON.parse(response.body)
      expect(newly_parsed['data']['id']).to eq(parsed['data']['id'])
    end

    it 'returns a unsuccessful response without mpi' do
      allow_any_instance_of(ClaimsApi::Veteran).to receive(:mpi_record?).and_return(false)
      post path, params: data, headers: headers
      expect(response.status).to eq(400)
    end

    it 'sets the source' do
      post path, params: data, headers: headers
      parsed = JSON.parse(response.body)
      token = parsed['data']['id']
      poa = ClaimsApi::PowerOfAttorney.find(token)
      expect(poa.source_data['name']).to eq('TestConsumer')
    end

    context 'validation' do
      let(:json_data) { JSON.parse data }

      it 'requires poa_code subfield' do
        params = json_data
        params['data']['attributes']['serviceOrganization']['poaCode'] = nil
        post path, params: params.to_json, headers: headers
        expect(response.status).to eq(422)
        expect(JSON.parse(response.body)['errors'].size).to eq(1)
      end
    end

    describe '#check status' do
      let(:power_of_attorney) { create(:power_of_attorney) }

      it 'increases the supporting document count' do
        get("/services/claims/v0/forms/2122/#{power_of_attorney.id}",
            params: nil, headers: headers)
        power_of_attorney.reload
        parsed = JSON.parse(response.body)
        expect(parsed['data']['type']).to eq('claims_api_power_of_attorneys')
        expect(parsed['data']['attributes']['status']).to eq('submitted')
      end
    end

    describe '#upload_power_of_attorney_document' do
      let(:power_of_attorney) { create(:power_of_attorney_without_doc) }
      let(:binary_params) do
        { 'attachment': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf") }
      end
      let(:base64_params) do
        { 'attachment': File.read("#{::Rails.root}/modules/claims_api/spec/fixtures/base64pdf") }
      end

      it 'submit binary and change the document status' do
        allow_any_instance_of(ClaimsApi::PowerOfAttorneyUploader).to receive(:store!)
        expect(power_of_attorney.file_data).to be_nil
        put("/services/claims/v0/forms/2122/#{power_of_attorney.id}",
            params: binary_params, headers: headers)
        power_of_attorney.reload
        expect(power_of_attorney.file_data).not_to be_nil
        expect(power_of_attorney.status).to eq('submitted')
      end

      it 'submit base64 and change the document status' do
        allow_any_instance_of(ClaimsApi::PowerOfAttorneyUploader).to receive(:store!)
        expect(power_of_attorney.file_data).to be_nil
        put("/services/claims/v0/forms/2122/#{power_of_attorney.id}",
            params: base64_params, headers: headers)
        power_of_attorney.reload
        expect(power_of_attorney.file_data).not_to be_nil
        expect(power_of_attorney.status).to eq('submitted')
      end
    end

    describe '#validate' do
      it 'returns a response when valid' do
        post "#{path}/validate", params: data, headers: headers
        parsed = JSON.parse(response.body)
        expect(parsed['data']['attributes']['status']).to eq('valid')
        expect(parsed['data']['type']).to eq('powerOfAttorneyValidation')
      end

      it 'returns a response when invalid' do
        post "#{path}/validate", params: { data: { attributes: nil } }.to_json, headers: headers
        parsed = JSON.parse(response.body)
        expect(response).to have_http_status(:unprocessable_entity)
        expect(parsed['errors']).not_to be_empty
      end

      it 'responds properly when JSON parse error' do
        post "#{path}/validate", params: 'hello', headers: headers
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
