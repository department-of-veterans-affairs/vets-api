# frozen_string_literal: true

# filepath: /Users/vicsaleem/MHV-Workspace/vets-api/spec/lib/sm/sm_client_spec.rb
require 'rails_helper'
require 'sm/sm_client' # Ensure this matches the file path of the SMClient class

RSpec.describe SM::SMClient do
  before(:all) do
    VCR.use_cassette('sm_client/session') do
      @client ||= begin
        client = SM::SMClient.new(session: { user_id: '10616687' })
        client.authenticate
        client
      end
    end
  end

  let(:session) { instance_double(SM::ClientSession, user_id: '17621060') } # Ensure user_id is mocked
  let(:client) { @client }

  describe '#auth_headers' do
    context 'when use_new_api is true' do
      it 'includes x-api-key in the headers' do
        allow(Settings.mhv.sm).to receive_messages(
          use_new_api: true,
          x_api_key: 'test-api-key',
          app_token: 'test-app-token'
        )
        headers = client.auth_headers
        expect(headers['x-api-key']).to eq('test-api-key')
        expect(headers['appToken']).to eq('test-app-token')
        expect(headers['mhvCorrelationId']).to eq('10616687')
      end
    end

    context 'when use_new_api is false' do
      let(:use_new_api) { false }

      before do
        allow(Settings.mhv.sm).to receive(:use_new_api).and_return(use_new_api)
        allow(Settings.mhv_mobile).to receive(:x_api_key).and_return(nil)
      end

      it 'does not include x-api-key in the headers' do
        allow(Settings.mhv.sm).to receive_messages(
          use_new_api: false,
          x_api_key: 'test-api-key',
          app_token: 'test-app-token'
        )
        headers = client.auth_headers
        expect(headers).not_to have_key('x-api-key')
        expect(headers['appToken']).to eq('test-app-token')
        expect(headers['mhvCorrelationId']).to eq('10616687')
      end
    end
  end

  describe '#get_headers' do
    it 'merges additional headers correctly' do
      base_headers = { 'Content-Type' => 'application/json' }
      allow(Settings.mhv.sm).to receive_messages(
        use_new_api: true,
        x_api_key: 'test-api-key'
      )
      headers = client.get_headers(base_headers)
      expect(headers['Content-Type']).to eq('application/json')
      expect(headers['x-api-key']).to eq('test-api-key')
    end

    it 'returns base headers when use_new_api is false' do
      base_headers = { 'Content-Type' => 'application/json' }
      allow(Settings.mhv.sm).to receive_messages(
        use_new_api: false,
        x_api_key: 'test-api-key',
        app_token: 'test-app-token'
      )
      headers = client.get_headers(base_headers)
      expect(headers['Content-Type']).to eq('application/json')
      expect(headers).not_to have_key('x-api-key')
    end
  end
end
