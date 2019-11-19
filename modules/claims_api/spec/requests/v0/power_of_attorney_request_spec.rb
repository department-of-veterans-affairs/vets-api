# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Power of Attorney ', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796043735',
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

    it 'returns a unsuccessful response without mvi' do
      allow_any_instance_of(ClaimsApi::Veteran).to receive(:mvi_record?).and_return(false)
      post path, params: data, headers: headers
      expect(response.status).to eq(404)
    end

    it 'sets the source' do
      post path, params: data, headers: headers
      token = JSON.parse(response.body)['data']['id']
      poa = ClaimsApi::PowerOfAttorney.find(token)
      expect(poa.source).to eq('TestConsumer')
    end

    context 'validation' do
      let(:json_data) { JSON.parse data }

      it 'requires poa_code subfield' do
        params = json_data
        params['data']['attributes']['poaCode'] = nil
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
      let(:params) do
        { 'attachment': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf") }
      end

      it 'increases the supporting document count' do
        allow_any_instance_of(ClaimsApi::PowerOfAttorneyUploader).to receive(:store!)
        expect(power_of_attorney.file_data).to be_nil
        put("/services/claims/v0/forms/2122/#{power_of_attorney.id}",
            params: params, headers: headers)
        power_of_attorney.reload
        expect(power_of_attorney.file_data).not_to be_nil
        expect(power_of_attorney.status).to eq('submitted')
      end
    end
  end
end
