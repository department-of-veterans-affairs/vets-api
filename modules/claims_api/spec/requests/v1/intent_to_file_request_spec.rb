# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Intent to file', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-10-4437',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-VA-EDIPI': '1007697216',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-User': 'adhoc.test.user',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[claim.write] }
  let(:path) { '/services/claims/v1/forms/0966' }
  let(:data) { { data: { attributes: { type: 'compensation' } } } }
  let(:extra) do
    { type: 'compensation',
      participant_claimant_id: 123_456_789,
      participant_vet_id: 987_654_321,
      received_date: '2015-01-05T17:42:12.058Z' }
  end
  let(:schema) { File.read(Rails.root.join('modules', 'claims_api', 'config', 'schemas', '0966.json')) }

  before do
    stub_poa_verification
    stub_mvi
  end

  describe '#0966' do
    it 'returns a successful get response with json schema' do
      with_okta_user(scopes) do |auth_header|
        get path, headers: headers.merge(auth_header)
        json_schema = JSON.parse(response.body)['data'][0]
        expect(json_schema).to eq(JSON.parse(schema))
      end
    end

    it 'posts a minimum payload and returns a payload with an expiration date' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
          post path, params: data.to_json, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('duplicate')
        end
      end
    end

    it 'posts a maximum payload and returns a payload with an expiration date' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file') do
          data['attributes'] = extra
          post path, params: data.to_json, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('duplicate')
        end
      end
    end

    it 'posts a 422 error with detail when BGS returns a 500 response' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/intent_to_file_web_service/insert_intent_to_file_500') do
          data['attributes'] = { type: 'pension' }
          post path, params: data.to_json, headers: headers.merge(auth_header)
          expect(response.status).to eq(422)
        end
      end
    end

    it "fails if passed a type that doesn't exist" do
      with_okta_user(scopes) do |auth_header|
        data[:data][:attributes][:type] = 'failingtesttype'
        post path, params: data.to_json, headers: headers.merge(auth_header)
        expect(response.status).to eq(422)
      end
    end

    it 'fails if none is passed in' do
      with_okta_user(scopes) do |auth_header|
        post path, headers: headers.merge(auth_header)
        expect(response.status).to eq(422)
      end
    end

    it 'fails if none is passed in as non-poa request' do
      with_okta_user(scopes) do |auth_header|
        post path, headers: auth_header, params: ''
        expect(response.status).to eq(422)
      end
    end
  end

  describe '#active' do
    it 'returns the latest itf of a compensation type' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
          get "#{path}/active", params: { type: 'compensation' }, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it 'returns the latest itf of a pension type' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
          get "#{path}/active", params: { type: 'pension' }, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it 'returns the latest itf of a burial type' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('bgs/intent_to_file_web_service/get_intent_to_file') do
          get "#{path}/active", params: { type: 'burial' }, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it 'fails if passed with wrong type' do
      with_okta_user(scopes) do |auth_header|
        get "#{path}/active", params: { type: 'test' }, headers: headers.merge(auth_header)
        expect(response.status).to eq(422)
      end
    end

    it 'fails if none is passed in for poa request' do
      with_okta_user(scopes) do |auth_header|
        get "#{path}/active", headers: headers.merge(auth_header)
        expect(response.status).to eq(400)
      end
    end

    it 'fails if none is passed in for non-poa request' do
      with_okta_user(scopes) do |auth_header|
        get "#{path}/active", headers: auth_header, params: ''
        expect(response.status).to eq(400)
      end
    end
  end

  describe '#validate' do
    it 'returns a response when valid' do
      with_okta_user(scopes) do |auth_header|
        post "#{path}/validate", params: data.to_json, headers: headers.merge(auth_header)
        parsed = JSON.parse(response.body)
        expect(parsed['data']['attributes']['status']).to eq('valid')
        expect(parsed['data']['type']).to eq('intentToFileValidation')
      end
    end

    it 'returns a response when invalid' do
      with_okta_user(scopes) do |auth_header|
        post "#{path}/validate", params: { data: { attributes: nil } }.to_json, headers: headers.merge(auth_header)
        parsed = JSON.parse(response.body)
        expect(response.status).to eq(422)
        expect(parsed['errors']).not_to be_empty
      end
    end

    it 'responds properly when JSON parse error' do
      with_okta_user(scopes) do |auth_header|
        post "#{path}/validate", params: 'hello', headers: headers.merge(auth_header)
        expect(response.status).to eq(422)
      end
    end
  end
end
