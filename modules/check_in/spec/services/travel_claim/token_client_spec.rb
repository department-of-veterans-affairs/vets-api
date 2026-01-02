# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TravelClaim::TokenClient do
  let(:client_number) { 'cn-123' }
  let(:client) { described_class.new(client_number) }
  let(:settings_double) do
    OpenStruct.new(
      auth_url: 'https://auth.example.test',
      tenant_id: 'tenant-123',
      travel_pay_client_id: 'client-id',
      travel_pay_client_secret: 'super-secret-123',
      claims_url_v2: 'https://claims.example.test',
      service_name: 'check-in-travel-pay',
      mock: false,
      subscription_key: 'sub-key',
      e_subscription_key: 'e-sub',
      s_subscription_key: 's-sub'
    )
  end
  let(:check_in_settings) { OpenStruct.new(travel_reimbursement_api_v2: settings_double) }

  before do
    allow(Settings).to receive_messages(check_in: check_in_settings, vsp_environment: 'dev')
  end

  describe '#veis_token' do
    it 'uses perform method to make VEIS token request' do
      mock_response = double('Response', body: { 'access_token' => 'test-token' }.to_json)

      expect(client).to receive(:perform).with(
        :post,
        '/tenant-123/oauth2/v2.0/token',
        kind_of(String),
        { 'Content-Type' => 'application/x-www-form-urlencoded' }
      ).and_return(mock_response)

      result = client.veis_token
      expect(result).to eq(mock_response)
    end

    it 'bubbles errors when VEIS returns non-200' do
      allow(client).to receive(:perform).and_raise(Common::Exceptions::BackendServiceException)

      expect do
        client.veis_token
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end
  end

  describe '#system_access_token_v4' do
    it 'uses perform method to make v4 system access token request' do
      mock_response = double('Response', body: { 'data' => { 'accessToken' => 'v4-token' } }.to_json)

      expect(client).to receive(:perform).with(
        :post,
        '/api/v4/auth/system-access-token',
        { secret: 'super-secret-123', icn: '123V456' },
        hash_including(
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer veis',
          'BTSSS-API-Client-Number' => 'cn-123'
        )
      ).and_return(mock_response)

      result = client.system_access_token_v4(veis_access_token: 'veis', icn: '123V456')
      expect(result).to eq(mock_response)
    end

    it 'uses E/S subscription keys in production' do
      allow(Settings).to receive(:vsp_environment).and_return('production')
      mock_response = double('Response', body: '{}')

      expect(client).to receive(:perform).with(
        :post,
        '/api/v4/auth/system-access-token',
        anything,
        hash_including(
          'Ocp-Apim-Subscription-Key-E' => 'e-sub',
          'Ocp-Apim-Subscription-Key-S' => 's-sub'
        )
      ).and_return(mock_response)

      client.system_access_token_v4(veis_access_token: 'x', icn: 'y')
    end

    it 'bubbles errors when service returns non-200' do
      allow(client).to receive(:perform).and_raise(Common::Exceptions::BackendServiceException)

      expect do
        client.system_access_token_v4(veis_access_token: 'veis', icn: '123V456')
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end
  end
end
