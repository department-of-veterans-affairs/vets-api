# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TravelClaim::TravelPayClient do
  let(:icn) { '1234567890V123456' }
  let(:client) { described_class.new(icn:) }
  let(:settings_double) do
    OpenStruct.new(
      auth_url: 'https://auth.example.test',
      tenant_id: 'tenant-123',
      travel_pay_client_id: 'client-id',
      travel_pay_client_secret: 'super-secret-123',
      travel_pay_client_number: 'client-number',
      scope: 'scope.read',
      claims_url_v2: 'https://claims.example.test',
      service_name: 'check-in-travel-pay',
      mock: false,
      subscription_key: 'sub-key',
      e_subscription_key: 'e-sub',
      s_subscription_key: 's-sub'
    )
  end
  let(:check_in_settings) { OpenStruct.new(travel_reimbursement_api_v2: settings_double) }
  let(:tokens) do
    {
      veis_token: 'veis-token-123',
      btsss_token: 'btsss-token-456'
    }
  end

  before do
    allow(Settings).to receive_messages(check_in: check_in_settings, vsp_environment: 'dev')
  end

  describe '#veis_token_request' do
    it 'makes VEIS token request with correct parameters' do
      mock_response = double('Response', body: { 'access_token' => 'test-token' }.to_json)

      expect(client).to receive(:perform).with(
        :post,
        'https://auth.example.test/tenant-123/oauth2/token',
        kind_of(String),
        { 'Content-Type' => 'application/x-www-form-urlencoded' }
      ).and_return(mock_response)

      result = client.veis_token_request
      expect(result).to eq(mock_response)
    end
  end

  describe '#system_access_token_request' do
    let(:client_number) { 'test-client-123' }
    let(:veis_access_token) { 'veis-token-abc' }
    let(:icn) { '1234567890V123456' }

    it 'makes system access token request with correct parameters' do
      mock_response = double('Response', body: { 'data' => { 'accessToken' => 'v4-token' } }.to_json)

      expect(client).to receive(:perform).with(
        :post,
        '/api/v4/auth/system-access-token',
        { secret: 'super-secret-123', icn: },
        hash_including(
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{veis_access_token}",
          'BTSSS-API-Client-Number' => client_number,
          'X-Correlation-ID' => anything
        )
      ).and_return(mock_response)

      result = client.system_access_token_request(
        client_number:,
        veis_access_token:,
        icn:
      )
      expect(result).to eq(mock_response)
    end
  end

  describe '#send_appointment_request' do
    let(:appointment_date_time) { '2024-01-15T10:00:00Z' }
    let(:facility_id) { 'facility-123' }
    let(:icn) { '1234567890V123456' }

    before do
      # Set up tokens
      client.instance_variable_set(:@current_veis_token, 'test-veis-token')
      client.instance_variable_set(:@current_btsss_token, 'test-btsss-token')
    end

    it 'makes appointment request with correct parameters' do
      mock_response = double('Response', body: { 'data' => { 'id' => 'appt-123' } }.to_json)

      expect(client).to receive(:perform).with(
        :post,
        '/api/v3/appointments/find-or-add',
        {
          appointmentDateTime: appointment_date_time,
          facilityStationNumber: facility_id
        },
        hash_including(
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer test-veis-token',
          'X-BTSSS-Token' => 'test-btsss-token',
          'X-Correlation-ID' => anything
        )
      ).and_return(mock_response)

      result = client.send_appointment_request(
        appointment_date_time:,
        facility_id:
      )
      expect(result).to eq(mock_response)
    end
  end

  describe '#config' do
    it 'returns the TravelClaim::Configuration instance' do
      expect(client.config).to eq(TravelClaim::Configuration.instance)
    end
  end

  describe 'initialization' do
    it 'raises error when ICN is blank' do
      expect { described_class.new(icn: '') }.to raise_error(ArgumentError, 'ICN cannot be blank')
      expect { described_class.new(icn: nil) }.to raise_error(ArgumentError, 'ICN cannot be blank')
    end
  end

  describe 'authentication' do
    it 'handles 401 errors by refreshing tokens and retrying' do
      # Set up tokens
      client.instance_variable_set(:@current_veis_token, 'test-veis-token')
      client.instance_variable_set(:@current_btsss_token, 'test-btsss-token')

      # First call raises 401, second call succeeds
      call_count = 0
      allow(client).to receive(:perform) do
        call_count += 1
        if call_count == 1
          raise Common::Exceptions::BackendServiceException.new('TEST', {}, 401, 'Unauthorized')
        else
          double('Response', status: 200, success?: true)
        end
      end
      expect(client).to receive(:refresh_tokens!)

      client.send(:with_auth) do
        client.send(:perform, :get, '/test', {}, {})
      end
    end

    it 'uses cached VEIS token from Redis when available' do
      allow(client.redis_client).to receive(:token).and_return('cached-veis')
      expect(client).to receive(:fetch_btsss_token!)

      client.send(:ensure_tokens!)

      expect(client.instance_variable_get(:@current_veis_token)).to eq('cached-veis')
    end

    it 'builds headers with current tokens' do
      client.instance_variable_set(:@current_veis_token, 'test-veis')
      client.instance_variable_set(:@current_btsss_token, 'test-btsss')

      headers = client.headers

      expect(headers['Authorization']).to eq('Bearer test-veis')
      expect(headers['X-BTSSS-Token']).to eq('test-btsss')
      expect(headers['X-Correlation-ID']).to eq(client.instance_variable_get(:@correlation_id))
    end

    it 'fetches fresh tokens when none are cached' do
      allow(client.redis_client).to receive(:token).and_return(nil)
      expect(client).to receive(:fetch_tokens!)

      client.send(:ensure_tokens!)
    end

    it 'refreshes tokens and clears cache' do
      client.instance_variable_set(:@current_veis_token, 'old-veis')
      client.instance_variable_set(:@current_btsss_token, 'old-btsss')
      expect(client).to receive(:fetch_tokens!)
      expect(client.redis_client).to receive(:save_token).with(token: nil)

      client.send(:refresh_tokens!)

      expect(client.instance_variable_get(:@current_veis_token)).to be_nil
      expect(client.instance_variable_get(:@current_btsss_token)).to be_nil
    end
  end

  describe '#subscription_key_headers' do
    it 'returns single subscription key for non-production environments' do
      allow(Settings).to receive(:vsp_environment).and_return('dev')

      headers = client.subscription_key_headers

      expect(headers).to eq({ 'Ocp-Apim-Subscription-Key' => 'sub-key' })
    end

    it 'returns separate E and S keys for production environment' do
      allow(Settings).to receive(:vsp_environment).and_return('production')

      headers = client.subscription_key_headers

      expect(headers).to eq({
                              'Ocp-Apim-Subscription-Key-E' => 'e-sub',
                              'Ocp-Apim-Subscription-Key-S' => 's-sub'
                            })
    end
  end
end
