# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Intent to file', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796104437',
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
  let(:data) { { 'data': { 'attributes': { 'type': 'compensation' } } } }
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

    it 'returns a payload with an expiration date' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/intent_to_file/create_compensation') do
          post path, params: data.to_json, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
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
        VCR.use_cassette('evss/intent_to_file/create_compensation') do
          post path, headers: headers.merge(auth_header)
          expect(response.status).to eq(422)
        end
      end
    end

    it 'fails if none is passed in as non-poa request' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/intent_to_file/create_compensation') do
          post path, headers: auth_header, params: ''
          expect(response.status).to eq(422)
        end
      end
    end
  end

  describe '#active' do
    it 'returns the latest itf of a type' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          get "#{path}/active", params: { type: 'compensation' }, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it 'fails if none is passed in for poa request' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          get "#{path}/active", headers: headers.merge(auth_header)
          expect(response.status).to eq(400)
        end
      end
    end

    it 'fails if none is passed in for non-poa request' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/intent_to_file/active_compensation') do
          get "#{path}/active", headers: auth_header, params: ''
          expect(response.status).to eq(400)
        end
      end
    end
  end
end
