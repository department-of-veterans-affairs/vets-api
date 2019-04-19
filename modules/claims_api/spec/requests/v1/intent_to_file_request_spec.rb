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

  before(:each) { stub_poa_verification }

  describe '#0966' do
    let(:data) { { 'data': { 'attributes': { 'type': 'compensation' } } } }

    it 'should return a payload with an expiration date' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/intent_to_file/create_compensation') do
          post path, params: data.to_json, headers: headers.merge(auth_header)
          expect(response.status).to eq(200)
          expect(JSON.parse(response.body)['data']['attributes']['status']).to eq('active')
        end
      end
    end

    it "should fail if passed a type that doesn't exist" do
      with_okta_user(scopes) do |auth_header|
        data[:data][:attributes][:type] = 'failingtesttype'
        post path, params: data.to_json, headers: headers.merge(auth_header)
        expect(response.status).to eq(422)
      end
    end

    it 'should default a type of compensation if none is passed in' do
      with_okta_user(scopes) do |auth_header|
        VCR.use_cassette('evss/intent_to_file/create_compensation') do
          post path, headers: headers.merge(auth_header)
          expect(JSON.parse(response.body)['data']['attributes']['type']).to eq('compensation')
        end
      end
    end
  end
end
