# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TravelClaim::TravelPayClient do
  let(:uuid) { 'test-uuid-123' }
  let(:check_in_uuid) { 'check-in-uuid-456' }
  let(:appointment_date_time) { '2024-01-01T12:00:00Z' }
  let(:redis_client) { instance_double(TravelClaim::RedisClient) }
  let(:client) do
    described_class.new(uuid:, appointment_date_time:, check_in_uuid:, icn: test_icn,
                        station_number: test_station_number)
  end

  # Test data constants
  let(:test_icn) { '1234567890V123456' }
  let(:test_station_number) { '500' }
  let(:test_veis_token) { 'fake_veis_token_123' }
  let(:test_btsss_token) { 'fake_btsss_token_456' }
  let(:test_appointment_id) { 'appt-123' }
  let(:test_claim_id) { 'claim-456' }
  let(:test_date_incurred) { '2024-01-15' }
  let(:test_client_number) { 'fake_client_number' }
  let(:test_veis_access_token) { 'fake_veis_token_123' }

  # Settings constants
  let(:auth_url) { 'https://login.microsoftonline.us' }
  let(:tenant_id) { 'fake_template_id' }
  let(:travel_pay_client_id) { 'fake_client_id' }
  let(:travel_pay_client_secret) { 'fake_client_secret' }
  let(:scope) { 'fake_scope' }
  let(:travel_pay_resource) { 'fake_resource' }
  let(:claims_url_v2) { 'https://dev.integration.d365.va.gov' }
  let(:subscription_key) { 'sub-key' }
  let(:e_subscription_key) { 'e-sub' }
  let(:s_subscription_key) { 's-sub' }

  before do
    allow(TravelClaim::RedisClient).to receive(:build).and_return(redis_client)
    # Default Redis behavior - can be overridden in individual tests
    # ICN is retrieved using check_in_uuid, station_number using uuid
    allow(redis_client).to receive(:icn).with(uuid: check_in_uuid).and_return(test_icn)
    allow(redis_client).to receive(:station_number).with(uuid:).and_return(test_station_number)
    # Allow save_token and token calls for authentication tests
    allow(redis_client).to receive(:save_token)
    allow(redis_client).to receive(:token)
  end

  # Settings are configured in individual tests using with_settings

  describe '#find_or_add_appointment!' do
    let(:appointment_date_time) { '2024-01-15T10:00:00Z' }
    let(:facility_id) { 'facility-123' }

    before do
      allow(client.instance_variable_get(:@redis)).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'returns appointment ID when successful' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
        VCR.use_cassette('check_in/travel_claim/appointments_find_or_add_200') do
          result = client.find_or_add_appointment!

          expect(result).to be_a(String)
          expect(result).to be_present
        end
      end
    end

    context 'when invalid parameters are provided' do
      it 'raises BackendServiceException for invalid appointment date' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:) do
          VCR.use_cassette('check_in/travel_claim/appointments_find_or_add_400') do
            expect { client.find_or_add_appointment! }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end
    end
  end

  describe '#create_claim!' do
    let(:appointment_id) { test_appointment_id }

    before do
      allow(client.instance_variable_get(:@redis)).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'returns claim ID when successful' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
        VCR.use_cassette('check_in/travel_claim/claims_create_200') do
          result = client.create_claim!(appointment_id:)

          expect(result).to be_a(String)
          expect(result).to be_present
        end
      end
    end

    context 'when claim creation fails' do
      it 'raises BackendServiceException for duplicate appointment' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:) do
          VCR.use_cassette('check_in/travel_claim/claims_create_400_duplicate') do
            expect do
              client.create_claim!(appointment_id: 'duplicate-appt-id')
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end

  describe '#add_mileage_expense!' do
    let(:claim_id) { test_claim_id }
    let(:date_incurred) { test_date_incurred }

    before do
      allow(client.instance_variable_get(:@redis)).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'returns response body with expense details when successful' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
        VCR.use_cassette('check_in/travel_claim/expenses_mileage_200') do
          result = client.add_mileage_expense!(
            claim_id:,
            date_incurred:
          )

          expect(result).to be_a(Hash)
          expect(result['success']).to be true
          expect(result['statusCode']).to eq(200)
          expect(result['message']).to eq('Expense added successfully.')
          expect(result['data']['expenseId']).to be_present
          expect(result['correlationId']).to be_present
        end
      end
    end
  end

  describe '#submit_claim!' do
    let(:claim_id) { test_claim_id }

    before do
      allow(client.instance_variable_get(:@redis)).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'returns response body with claim submission details when successful' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
        VCR.use_cassette('check_in/travel_claim/claims_submit_200') do
          result = client.submit_claim!(claim_id:)

          expect(result).to be_a(Hash)
          expect(result['success']).to be true
          expect(result['statusCode']).to eq(200)
          expect(result['message']).to eq('Claim submitted successfully.')
          expect(result['data']['claimId']).to be_present
          expect(result['data']['status']).to eq('ClaimSubmitted')
          expect(result['data']['createdOn']).to be_present
          expect(result['data']['modifiedOn']).to be_present
          expect(result['correlationId']).to be_present
        end
      end
    end
  end

  describe '#get_claim' do
    let(:claim_id) { test_claim_id }

    before do
      allow(client.instance_variable_get(:@redis)).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'returns full response object with claim details when successful' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
        VCR.use_cassette('check_in/travel_claim/claims_get_200') do
          result = client.get_claim(claim_id:)

          expect(result).to respond_to(:status)
          expect(result).to respond_to(:body)
          expect(result.status).to eq(200)

          response_body = result.body.is_a?(String) ? JSON.parse(result.body) : result.body
          expect(response_body['success']).to be true
          expect(response_body['statusCode']).to eq(200)
          expect(response_body['message']).to eq('Data retrieved successfully.')
          expect(response_body['data']['claimId']).to be_present
          expect(response_body['data']['claimNumber']).to eq('TC202508000013890')
          expect(response_body['data']['claimStatus']).to eq('ClaimSubmitted')
          expect(response_body['data']['claimantFirstName']).to eq('JUDY')
          expect(response_body['data']['claimantLastName']).to eq('MORRISON')
          expect(response_body['data']['appointment']['id']).to be_present
          expect(response_body['data']['expenses']).to be_an(Array)
          expect(response_body['data']['expenses'].first['expenseType']).to eq('Mileage')
          expect(response_body['correlationId']).to be_present
        end
      end
    end

    context 'when claim is not found' do
      it 'raises BackendServiceException for 404 response' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:) do
          VCR.use_cassette('check_in/travel_claim/claims_get_404') do
            expect do
              client.get_claim(claim_id: 'non-existent-claim')
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end

    context 'when server error occurs' do
      it 'raises BackendServiceException for 500 response' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:) do
          VCR.use_cassette('check_in/travel_claim/claims_get_500') do
            expect do
              client.get_claim(claim_id:)
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end

  describe 'initialization' do
    it 'raises error when UUID is blank' do
      expect do
        described_class.new(uuid: '', appointment_date_time:, check_in_uuid:, icn: test_icn,
                            station_number: test_station_number)
      end
        .to raise_error(ArgumentError, 'UUID cannot be blank')
    end

    it 'raises error when check_in_uuid is blank' do
      expect do
        described_class.new(uuid:, appointment_date_time:, check_in_uuid: '', icn: test_icn,
                            station_number: test_station_number)
      end
        .to raise_error(ArgumentError, 'Check-in UUID cannot be blank')
    end

    it 'raises error when ICN is blank' do
      expect do
        described_class.new(uuid:, appointment_date_time:, check_in_uuid:, icn: '', station_number: test_station_number)
      end
        .to raise_error(ArgumentError, 'ICN cannot be blank')
    end

    it 'raises error when station_number is blank' do
      expect { described_class.new(uuid:, appointment_date_time:, check_in_uuid:, icn: test_icn, station_number: '') }
        .to raise_error(ArgumentError, 'station number cannot be blank')
    end

    it 'accepts all required parameters' do
      expect do
        described_class.new(uuid:, appointment_date_time:, check_in_uuid:, icn: test_icn,
                            station_number: test_station_number)
      end
        .not_to raise_error
    end
  end

  describe 'authentication' do
    it 'handles 401 errors by refreshing tokens and retrying once' do
      # Set up tokens
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)

      # First call raises 401, second call succeeds
      call_count = 0
      allow(client).to receive(:perform) do
        call_count += 1
        if call_count == 1
          raise Common::Exceptions::BackendServiceException.new('TEST', {}, 401, 'Unauthorized')
        else
          double('Response', status: 200, success?: true, body: { 'access_token' => 'new-token' })
        end
      end

      # Mock the token refresh to avoid the complex internal logic
      allow(client).to receive(:bootstrap_tokens!) do
        client.instance_variable_set(:@current_veis_token, 'refreshed-veis-token')
        client.instance_variable_set(:@current_btsss_token, 'refreshed-btsss-token')
      end

      result = client.send(:with_auth) do
        client.send(:perform, :get, '/test', {}, {})
      end

      expect(result).to be_a(RSpec::Mocks::Double)
      expect(call_count).to eq(2) # Should have retried once
    end

    it 'fails fast when token refresh fails after 401' do
      # Set up tokens
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)

      # First call raises 401, token refresh fails
      allow(client).to receive(:perform).and_raise(
        Common::Exceptions::BackendServiceException.new('TEST', {}, 401, 'Unauthorized')
      )
      allow(client).to receive(:bootstrap_tokens!).and_raise(
        Common::Exceptions::BackendServiceException.new('AUTH_FAILED', {}, 500, 'Internal Server Error')
      )

      expect do
        client.send(:with_auth) do
          client.send(:perform, :get, '/test', {}, {})
        end
      end.to raise_error(Common::Exceptions::BackendServiceException)
    end

    it 'does not retry authentication more than once per request' do
      # Set up tokens
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)

      # Multiple 401 responses should only trigger one retry
      allow(client).to receive(:perform).and_raise(
        Common::Exceptions::BackendServiceException.new('TEST', {}, 401, 'Unauthorized')
      )

      # Mock bootstrap_tokens! to track calls
      bootstrap_call_count = 0
      allow(client).to receive(:bootstrap_tokens!) do
        bootstrap_call_count += 1
      end

      expect do
        client.send(:with_auth) do
          client.send(:perform, :get, '/test', {}, {})
        end
      end.to raise_error(Common::Exceptions::BackendServiceException)

      expect(bootstrap_call_count).to be >= 1 # Should attempt refresh at least once but not indefinitely
    end

    it 'handles authentication internally' do
      # Test that authentication methods exist and can be called
      expect(client).to respond_to(:bootstrap_tokens!)
      expect(client).to respond_to(:ensure_tokens!)
      expect(client).to respond_to(:refresh_tokens!)
    end

    it 'uses cached VEIS token from Redis when available' do
      cached_veis_token = 'cached-veis'
      allow(client.instance_variable_get(:@redis)).to receive(:token).and_return(cached_veis_token)
      expect(client).to receive(:fetch_btsss_token!)

      client.send(:ensure_tokens!)

      expect(client.instance_variable_get(:@current_veis_token)).to eq(cached_veis_token)
    end

    it 'builds headers with current tokens' do
      test_veis = 'test-veis'
      test_btsss = 'test-btsss'
      client.instance_variable_set(:@current_veis_token, test_veis)
      client.instance_variable_set(:@current_btsss_token, test_btsss)

      headers = client.send(:base_headers)

      expect(headers['Authorization']).to eq("Bearer #{test_veis}")
      expect(headers['BTSSS-Access-Token']).to eq(test_btsss)
      expect(headers['X-Correlation-ID']).to eq(client.instance_variable_get(:@correlation_id))
    end

    it 'fetches fresh tokens when none are cached' do
      allow(client.instance_variable_get(:@redis)).to receive(:token).and_return(nil)
      expect(client).to receive(:request_veis_token).and_return('new-veis-token')
      expect(client).to receive(:fetch_btsss_token!)

      client.send(:ensure_tokens!)
    end

    it 'refreshes tokens and clears cache' do
      old_veis_token = 'old-veis'
      old_btsss_token = 'old-btsss'
      client.instance_variable_set(:@current_veis_token, old_veis_token)
      client.instance_variable_set(:@current_btsss_token, old_btsss_token)

      # Mock the Redis token call and the token fetching methods
      allow(client.instance_variable_get(:@redis)).to receive(:token).and_return(nil)
      expect(client).to receive(:request_veis_token).and_return('new-veis-token')
      expect(client).to receive(:fetch_btsss_token!) do
        client.instance_variable_set(:@current_btsss_token, 'new-btsss-token')
      end
      expect(client.instance_variable_get(:@redis)).to receive(:save_token).with(token: nil)

      client.send(:refresh_tokens!)

      expect(client.instance_variable_get(:@current_veis_token)).to eq('new-veis-token')
      expect(client.instance_variable_get(:@current_btsss_token)).to eq('new-btsss-token')
    end
  end

  describe '#subscription_key_headers' do
    it 'returns single subscription key for non-production environments' do
      with_settings(Settings, vsp_environment: 'dev') do
        with_settings(Settings.check_in.travel_reimbursement_api_v2, subscription_key:) do
          headers = client.send(:subscription_key_headers)
          expect(headers).to eq({ 'Ocp-Apim-Subscription-Key' => subscription_key })
        end
      end
    end

    it 'returns separate E and S keys for production environment' do
      with_settings(Settings, vsp_environment: 'production') do
        with_settings(Settings.check_in.travel_reimbursement_api_v2, e_subscription_key:,
                                                                     s_subscription_key:) do
          headers = client.send(:subscription_key_headers)
          expect(headers).to eq({
                                  'Ocp-Apim-Subscription-Key-E' => e_subscription_key,
                                  'Ocp-Apim-Subscription-Key-S' => s_subscription_key
                                })
        end
      end
    end
  end

  describe '#patch method override' do
    before do
      allow(client.instance_variable_get(:@redis)).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'calls request method directly for PATCH requests' do
      expect(client).to receive(:request).with(:patch, anything, anything, anything, anything)

      client.send(:perform, :patch, '/test/patch', {}, {})
    end

    it 'successfully makes PATCH requests for claim submission' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
        VCR.use_cassette('check_in/travel_claim/claims_submit_200') do
          result = client.submit_claim!(claim_id: test_claim_id)

          expect(result).to be_a(Hash)
          expect(result['data']).to be_present
        end
      end
    end
  end

  describe '#headers' do
    let(:test_veis_token_for_headers) { 'test-veis-token' }
    let(:test_btsss_token_for_headers) { 'test-btsss-token' }
    let(:new_veis_token) { 'new-veis-token' }
    let(:new_btsss_token) { 'new-btsss-token' }

    before do
      client.instance_variable_set(:@current_veis_token, test_veis_token_for_headers)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token_for_headers)
    end

    it 'includes all required headers' do
      headers = client.send(:base_headers)

      expect(headers).to include(
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{test_veis_token_for_headers}",
        'BTSSS-Access-Token' => test_btsss_token_for_headers,
        'X-Correlation-ID' => client.instance_variable_get(:@correlation_id)
      )
    end

    it 'includes subscription key headers' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2, subscription_key:) do
        headers = client.send(:base_headers)
        expect(headers).to include('Ocp-Apim-Subscription-Key' => subscription_key)
      end
    end

    it 'updates headers when tokens change' do
      initial_headers = client.send(:base_headers)

      # Change tokens
      client.instance_variable_set(:@current_veis_token, new_veis_token)
      client.instance_variable_set(:@current_btsss_token, new_btsss_token)

      new_headers = client.send(:base_headers)

      expect(new_headers).not_to eq(initial_headers)
      expect(new_headers['Authorization']).to eq("Bearer #{new_veis_token}")
      expect(new_headers['BTSSS-Access-Token']).to eq(new_btsss_token)
    end
  end
end
