# frozen_string_literal: true

require 'rails_helper'
require 'rx/medications_client'

RSpec.describe Rx::MedicationsClient do
  before(:all) do
    VCR.use_cassette 'rx_client/session' do
      @client ||= begin
        client = Rx::MedicationsClient.new(session: { user_id: '12345' })
        client.authenticate
        client
      end
    end
  end

  let(:session) { instance_double(Rx::ClientSession, user_id: '17621060') } # Ensure user_id is mocked
  let(:client) { @client }

  describe '#auth_headers' do
    context 'when use_new_api is true' do
      it 'includes x-api-key in the headers' do
        allow(Settings.mhv.rx).to receive_messages(
          use_new_api: true,
          x_api_key: 'fake-x-api-key',
          app_token: 'va_gov_token'
        )
        headers = client.auth_headers
        expect(headers['x-api-key']).to eq('fake-x-api-key')
        expect(headers['appToken']).to eq('va_gov_token')
        expect(headers['mhvCorrelationId']).to eq('12345')
      end
    end

    context 'when use_new_api is false' do
      it 'does not include x-api-key in the headers' do
        allow(Settings.mhv.rx).to receive_messages(
          use_new_api: false,
          x_api_key: 'fake-x-api-key',
          app_token: 'va_gov_token'
        )
        headers = client.auth_headers
        expect(headers).not_to have_key('x-api-key')
        expect(headers['appToken']).to eq('va_gov_token')
        expect(headers['mhvCorrelationId']).to eq('12345')
      end
    end
  end

  describe '#get_headers' do
    it 'merges additional headers correctly' do
      base_headers = { 'Content-Type' => 'application/json' }
      allow(Settings.mhv.rx).to receive_messages(
        use_new_api: true,
        x_api_key: 'fake-x-api-key'
      )
      headers = client.get_headers(base_headers)
      expect(headers['Content-Type']).to eq('application/json')
      expect(headers['x-api-key']).to eq('fake-x-api-key')
    end

    it 'returns base headers when use_new_api is false' do
      base_headers = { 'Content-Type' => 'application/json' }
      allow(Settings.mhv.rx).to receive_messages(
        use_new_api: false,
        x_api_key: 'fake-x-api-key',
        app_token: 'va_gov_token'
      )
      headers = client.get_headers(base_headers)
      expect(headers['Content-Type']).to eq('application/json')
      expect(headers).not_to have_key('x-api-key')
    end
  end
end
