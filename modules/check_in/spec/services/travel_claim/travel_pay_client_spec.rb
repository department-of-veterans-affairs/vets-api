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
        '/tenant-123/oauth2/v2.0/token',
        kind_of(String),
        { 'Content-Type' => 'application/x-www-form-urlencoded' }
      ).and_return(mock_response)

      result = client.veis_token_request
      expect(result).to eq(mock_response)
    end

    it 'builds correct request body' do
      allow(client).to receive(:perform) do |_method, _path, body, _headers|
        expect(body).to include('client_id=client-id')
        expect(body).to include('client_secret=super-secret-123')
        expect(body).to include('scope=scope.read')
        expect(body).to include('grant_type=client_credentials')
      end

      client.veis_token_request
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

    it 'uses default client number when not provided' do
      mock_response = double('Response', body: '{}')

      expect(client).to receive(:perform) do |_method, _path, _body, headers|
        expect(headers['BTSSS-API-Client-Number']).to eq('client-number')
      end.and_return(mock_response)

      client.system_access_token_request(
        client_number: nil,
        veis_access_token:,
        icn:
      )
    end

    it 'includes correlation ID in headers' do
      mock_response = double('Response', body: '{}')
      correlation_id = client.instance_variable_get(:@correlation_id)

      expect(client).to receive(:perform) do |_method, _path, _body, headers|
        expect(headers['X-Correlation-ID']).to eq(correlation_id)
      end.and_return(mock_response)

      client.system_access_token_request(
        client_number:,
        veis_access_token:,
        icn:
      )
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

      client.system_access_token_request(
        client_number:,
        veis_access_token:,
        icn:
      )
    end

    it 'uses single subscription key in non-production' do
      mock_response = double('Response', body: '{}')

      expect(client).to receive(:perform).with(
        :post,
        '/api/v4/auth/system-access-token',
        anything,
        hash_including('Ocp-Apim-Subscription-Key' => 'sub-key')
      ).and_return(mock_response)

      client.system_access_token_request(
        client_number:,
        veis_access_token:,
        icn:
      )
    end

    it 'bubbles errors when service returns non-200' do
      allow(client).to receive(:perform).and_raise(Common::Exceptions::BackendServiceException)

      expect do
        client.system_access_token_request(
          client_number:,
          veis_access_token:,
          icn:
        )
      end.to raise_error(Common::Exceptions::BackendServiceException)
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

    it 'includes correlation ID in headers' do
      mock_response = double('Response', body: '{}')
      correlation_id = client.instance_variable_get(:@correlation_id)

      expect(client).to receive(:perform) do |_method, _path, _body, headers|
        expect(headers['X-Correlation-ID']).to eq(correlation_id)
      end.and_return(mock_response)

      client.send_appointment_request(
        appointment_date_time:,
        facility_id:
      )
    end
  end

  describe '#subscription_key_headers' do
    context 'in production environment' do
      before { allow(Settings).to receive(:vsp_environment).and_return('production') }

      it 'returns E and S subscription keys' do
        headers = client.subscription_key_headers

        expect(headers).to eq({
                                'Ocp-Apim-Subscription-Key-E' => 'e-sub',
                                'Ocp-Apim-Subscription-Key-S' => 's-sub'
                              })
      end
    end

    context 'in non-production environment' do
      before { allow(Settings).to receive(:vsp_environment).and_return('dev') }

      it 'returns single subscription key' do
        headers = client.subscription_key_headers

        expect(headers).to eq({ 'Ocp-Apim-Subscription-Key' => 'sub-key' })
      end
    end
  end

  describe 'correlation_id management' do
    it 'generates a correlation ID on initialization' do
      expect(client.instance_variable_get(:@correlation_id)).to be_a(String)
      expect(client.instance_variable_get(:@correlation_id)).not_to be_empty
    end

    it 'reuses the same correlation ID across requests' do
      correlation_id = client.instance_variable_get(:@correlation_id)

      # Set up tokens
      client.instance_variable_set(:@current_veis_token, 'test-veis-token')
      client.instance_variable_set(:@current_btsss_token, 'test-btsss-token')

      # Mock multiple requests and verify they all use the same correlation ID
      expect(client).to receive(:perform).twice do |_method, _path, _body, headers|
        expect(headers['X-Correlation-ID']).to eq(correlation_id)
      end.and_return(double('Response', body: '{}'))

      client.system_access_token_request(
        client_number: 'test',
        veis_access_token: 'token',
        icn: '123'
      )

      client.send_appointment_request(
        appointment_date_time: '2024-01-15T10:00:00Z',
        facility_id: 'facility-123'
      )
    end
  end

  describe '#headers' do
    before do
      client.instance_variable_set(:@current_veis_token, 'test-veis-token')
      client.instance_variable_set(:@current_btsss_token, 'test-btsss-token')
    end

    it 'rebuilds headers when tokens change' do
      initial_headers = client.headers

      # Change tokens
      client.instance_variable_set(:@current_veis_token, 'new-veis-token')
      client.instance_variable_set(:@current_btsss_token, 'new-btsss-token')

      # Clear memoized headers
      client.instance_variable_set(:@headers, nil)

      new_headers = client.headers

      expect(new_headers).not_to eq(initial_headers)
      expect(new_headers['Authorization']).to eq('Bearer new-veis-token')
      expect(new_headers['X-BTSSS-Token']).to eq('new-btsss-token')
    end

    it 'includes all required headers' do
      headers = client.headers

      expect(headers).to include(
        'Content-Type' => 'application/json',
        'Authorization' => 'Bearer test-veis-token',
        'X-BTSSS-Token' => 'test-btsss-token',
        'X-Correlation-ID' => client.instance_variable_get(:@correlation_id)
      )
    end

    it 'includes subscription key headers' do
      headers = client.headers
      expect(headers).to include('Ocp-Apim-Subscription-Key' => 'sub-key')
    end
  end

  describe '#config' do
    it 'returns the TravelClaim::Configuration instance' do
      expect(client.config).to eq(TravelClaim::Configuration.instance)
    end
  end

  describe 'authentication methods' do
    let(:icn) { '1234567890V123456' }

    describe '#with_auth' do
      before do
        client.instance_variable_set(:@current_veis_token, 'test-veis-token')
        client.instance_variable_set(:@current_btsss_token, 'test-btsss-token')
      end

      it 'yields when tokens are available' do
        result = client.send(:with_auth) { 'success' }
        expect(result).to eq('success')
      end

      it 'refreshes tokens and retries on 401' do
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
    end

    describe '#ensure_tokens!' do
      it 'fetches tokens when none are available' do
        allow(client.redis_client).to receive(:token).and_return(nil)
        allow(client.redis_client).to receive(:v4_token).with(cache_key: "btsss_#{icn}").and_return(nil)
        expect(client).to receive(:fetch_tokens!)
        client.send(:ensure_tokens!)
      end

      it 'uses cached tokens from Redis when available' do
        allow(client.redis_client).to receive(:token).and_return('cached-veis')
        allow(client.redis_client).to receive(:v4_token).with(cache_key: "btsss_#{icn}").and_return('cached-btsss')

        client.send(:ensure_tokens!)

        expect(client.instance_variable_get(:@current_veis_token)).to eq('cached-veis')
        expect(client.instance_variable_get(:@current_btsss_token)).to eq('cached-btsss')
      end

      it 'does not fetch tokens when they are already available' do
        client.instance_variable_set(:@current_veis_token, 'test-veis-token')
        client.instance_variable_set(:@current_btsss_token, 'test-btsss-token')

        expect(client).not_to receive(:fetch_tokens!)
        client.send(:ensure_tokens!)
      end
    end

    describe '#fetch_tokens!' do
      it 'fetches both VEIS and BTSSS tokens and stores them in Redis' do
        veis_response = double('Response', success?: true, body: { 'access_token' => 'veis-token' })
        btsss_response = double('Response', success?: true, body: { 'access_token' => 'btsss-token' })

        expect(client).to receive(:veis_token_request).and_return(veis_response)
        expect(client).to receive(:system_access_token_request).with(
          client_number: nil,
          veis_access_token: 'veis-token',
          icn:
        ).and_return(btsss_response)
        expect(client.redis_client).to receive(:save_token).with(token: 'veis-token')
        expect(client.redis_client).to receive(:save_v4_token).with(cache_key: "btsss_#{icn}", token: 'btsss-token')

        client.send(:fetch_tokens!)

        expect(client.instance_variable_get(:@current_veis_token)).to eq('veis-token')
        expect(client.instance_variable_get(:@current_btsss_token)).to eq('btsss-token')
      end
    end

    describe '#refresh_tokens!' do
      it 'clears current tokens and fetches new ones' do
        client.instance_variable_set(:@current_veis_token, 'old-veis-token')
        client.instance_variable_set(:@current_btsss_token, 'old-btsss-token')

        expect(client.redis_client).to receive(:save_token).with(token: nil)
        expect(client.redis_client).to receive(:save_v4_token).with(cache_key: "btsss_#{icn}", token: nil)
        expect(client).to receive(:fetch_tokens!)

        client.send(:refresh_tokens!)

        expect(client.instance_variable_get(:@current_veis_token)).to be_nil
        expect(client.instance_variable_get(:@current_btsss_token)).to be_nil
      end
    end
  end
end
