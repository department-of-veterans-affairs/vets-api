# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Intent to file', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-10-4437',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-LOA' => '3',
      'X-VA-Gender': 'M' }
  end
  let(:path) { '/services/claims/v0/forms/0966' }
  let(:data) { { data: { attributes: { type: 'compensation' } } } }
  let(:extra) do
    { type: 'compensation',
      participant_claimant_id: 123_456_789,
      participant_vet_id: 987_654_321,
      received_date: '2015-01-05T17:42:12.058Z' }
  end
  let(:schema) { File.read(Rails.root.join('modules', 'claims_api', 'config', 'schemas', '0966.json')) }

  describe '#0966' do
    it 'returns a successful get response with json schema' do
      get path, headers: headers
      json_schema = JSON.parse(response.body)['data'][0]
      expect(json_schema).to eq(JSON.parse(schema))
    end

    it 'posts a minimum payload and returns a payload with an expiration date' do
      VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
        post path, params: data.to_json, headers: headers
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('duplicate')
      end
    end

    it 'posts a maximum payload and returns a payload with an expiration date' do
      VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
        data['attributes'] = extra
        post path, params: data.to_json, headers: headers
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('duplicate')
      end
    end

    it 'posts a 422 error with detail when BGS returns a 500 response' do
      VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file_500') do
        data['attributes'] = { type: 'pension' }
        post path, params: data.to_json, headers: headers
        expect(response.status).to eq(422)
      end
    end

    it "fails if passed a type that doesn't exist" do
      data[:data][:attributes][:type] = 'failingtesttype'
      post path, params: data.to_json, headers: headers
      expect(response.status).to eq(422)
    end

    it 'fails if none is passed in' do
      post path, headers: headers
      expect(response.status).to eq(422)
    end

    it "returns a 403 when 'burial' type is provided" do
      data[:data][:attributes][:type] = 'burial'
      post path, params: data.to_json, headers: headers
      expect(response.status).to eq(403)
    end
  end

  describe '#active' do
    before do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
    end

    after do
      Timecop.return
    end

    it 'returns the latest itf of a compensation type' do
      VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
        get "#{path}/active", params: { type: 'compensation' }, headers: headers
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
      end
    end

    it 'returns the latest itf of a pension type' do
      VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
        get "#{path}/active", params: { type: 'pension' }, headers: headers
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
      end
    end

    it 'returns the latest itf of a burial type' do
      VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
        get "#{path}/active", params: { type: 'burial' }, headers: headers
        expect(response.status).to eq(200)
        expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
      end
    end

    it 'fails if passed wrong type' do
      get "#{path}/active", params: { type: 'test' }, headers: headers
      expect(response.status).to eq(422)
    end

    it 'fails if none is passed in' do
      get "#{path}/active", headers: headers
      expect(response.status).to eq(400)
    end
  end

  describe '#validate' do
    it 'returns a response when valid' do
      post "#{path}/validate", params: data.to_json, headers: headers
      parsed = JSON.parse(response.body)
      expect(parsed['data']['attributes']['status']).to eq('valid')
      expect(parsed['data']['type']).to eq('intentToFileValidation')
    end

    it 'returns a response when invalid' do
      post "#{path}/validate", params: { data: { attributes: nil } }.to_json, headers: headers
      parsed = JSON.parse(response.body)
      expect(response.status).to eq(422)
      expect(parsed['errors']).not_to be_empty
    end

    it 'responds properly when JSON parse error' do
      post "#{path}/validate", params: 'hello', headers: headers
      expect(response.status).to eq(422)
    end
  end
end
