# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TravelClaim::TravelPayClient do
  let(:uuid) { 'test-uuid-123' }
  let(:appointment_date_time) { '2024-01-01T12:00:00Z' }
  let(:redis_client) { instance_double(TravelClaim::RedisClient) }
  let(:client) { described_class.new(uuid:, appointment_date_time:) }

  before do
    allow(TravelClaim::RedisClient).to receive(:build).and_return(redis_client)
    allow(redis_client).to receive(:icn).with(uuid:).and_return('1234567890V123456')
    allow(redis_client).to receive(:station_number).with(uuid:).and_return('500')
  end

  # Settings are configured in individual tests using with_settings

  describe '#veis_token_request' do
    it 'makes VEIS token request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    auth_url: 'https://dev.integration.d365.va.gov',
                    tenant_id: 'fake_template_id',
                    travel_pay_client_id: 'fake_client_id',
                    travel_pay_client_secret: 'fake_client_secret',
                    scope: 'fake_scope',
                    travel_pay_resource: 'fake_resource') do
        VCR.use_cassette('check_in/travel_claim/veis_token_200') do
          result = client.veis_token_request

          expect(result).to respond_to(:status)
          expect(result).to respond_to(:body)
          expect(result.status).to eq(200)

          response_body = result.body.is_a?(String) ? JSON.parse(result.body) : result.body
          expect(response_body['access_token']).to be_present
          expect(response_body['token_type']).to eq('Bearer')
          expect(response_body['expires_in']).to be_present
        end
      end
    end
  end

  describe '#system_access_token_request' do
    let(:client_number) { 'fake_client_number' }
    let(:veis_access_token) { 'fake_veis_token_123' }

    it 'makes system access token request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/system_access_token_200') do
          result = client.send(:system_access_token_request,
                               client_number: 'test-client',
                               veis_access_token: 'test-veis-token',
                               icn: '1234567890V123456')

          expect(result).to respond_to(:status)
          expect(result.status).to eq(200)
        end
      end
    end
  end

  describe '#send_appointment_request' do
    let(:appointment_date_time) { '2024-01-15T10:00:00Z' }
    let(:facility_id) { 'facility-123' }

    before do
      allow(client.redis_client).to receive(:token).and_return('fake_veis_token_123')
      client.instance_variable_set(:@current_veis_token, 'fake_veis_token_123')
      client.instance_variable_set(:@current_btsss_token, 'fake_btsss_token_456')
    end

    it 'makes appointment request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/appointments_find_or_add_200') do
          result = client.send_appointment_request

          expect(result).to respond_to(:status)
          expect(result.status).to eq(200)
        end
      end
    end

    context 'when invalid parameters are provided' do
      it 'raises BackendServiceException for invalid appointment date' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2: 'https://dev.integration.d365.va.gov') do
          VCR.use_cassette('check_in/travel_claim/appointments_find_or_add_400') do
            expect { client.send_appointment_request }.to raise_error(
              Common::Exceptions::BackendServiceException
            )
          end
        end
      end
    end
  end

  describe '#send_claim_request' do
    let(:appointment_id) { 'appt-123' }

    before do
      allow(client.redis_client).to receive(:token).and_return('fake_veis_token_123')
      client.instance_variable_set(:@current_veis_token, 'fake_veis_token_123')
      client.instance_variable_set(:@current_btsss_token, 'fake_btsss_token_456')
    end

    it 'makes claim request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/claims_create_200') do
          result = client.send_claim_request(appointment_id:)

          expect(result).to respond_to(:status)
          expect(result).to respond_to(:body)
          expect(result.status).to eq(200)

          response_body = result.body.is_a?(String) ? JSON.parse(result.body) : result.body
          expect(response_body['success']).to be true
          expect(response_body['statusCode']).to eq(200)
          expect(response_body['message']).to eq('Claim created successfully.')
          expect(response_body['data']['claimId']).to be_present
          expect(response_body['correlationId']).to be_present
        end
      end
    end

    context 'when claim creation fails' do
      it 'raises BackendServiceException for duplicate appointment' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2: 'https://dev.integration.d365.va.gov') do
          VCR.use_cassette('check_in/travel_claim/claims_create_400_duplicate') do
            expect do
              client.send_claim_request(appointment_id: 'duplicate-appt-id')
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end

  describe '#send_get_claim_request' do
    let(:claim_id) { 'claim-123' }

    before do
      allow(client.redis_client).to receive(:token).and_return('fake_veis_token_123')
      client.instance_variable_set(:@current_veis_token, 'fake_veis_token_123')
      client.instance_variable_set(:@current_btsss_token, 'fake_btsss_token_456')
    end

    it 'makes get claim request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/claims_get_200') do
          result = client.send_get_claim_request(claim_id:)

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
                      claims_url_v2: 'https://dev.integration.d365.va.gov') do
          VCR.use_cassette('check_in/travel_claim/claims_get_404') do
            expect do
              client.send_get_claim_request(claim_id: 'non-existent-claim')
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end

    context 'when server error occurs' do
      it 'raises BackendServiceException for 500 response' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2: 'https://dev.integration.d365.va.gov') do
          VCR.use_cassette('check_in/travel_claim/claims_get_500') do
            expect do
              client.send_get_claim_request(claim_id:)
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end

  describe '#send_mileage_expense_request' do
    let(:claim_id) { 'claim-123' }
    let(:date_incurred) { '2024-01-15' }

    before do
      allow(client.redis_client).to receive(:token).and_return('fake_veis_token_123')
      client.instance_variable_set(:@current_veis_token, 'fake_veis_token_123')
      client.instance_variable_set(:@current_btsss_token, 'fake_btsss_token_456')
    end

    it 'makes mileage expense request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/expenses_mileage_200') do
          result = client.send_mileage_expense_request(
            claim_id:,
            date_incurred:
          )

          expect(result).to respond_to(:status)
          expect(result).to respond_to(:body)
          expect(result.status).to eq(200)

          response_body = result.body.is_a?(String) ? JSON.parse(result.body) : result.body
          expect(response_body['success']).to be true
          expect(response_body['statusCode']).to eq(200)
          expect(response_body['message']).to eq('Expense added successfully.')
          expect(response_body['data']['expenseId']).to be_present
          expect(response_body['correlationId']).to be_present
        end
      end
    end
  end

  describe '#send_claim_submission_request' do
    let(:claim_id) { 'claim-123' }

    before do
      allow(client.redis_client).to receive(:token).and_return('fake_veis_token_123')
      client.instance_variable_set(:@current_veis_token, 'fake_veis_token_123')
      client.instance_variable_set(:@current_btsss_token, 'fake_btsss_token_456')
    end

    it 'makes claim submission request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/claims_submit_200') do
          result = client.send_claim_submission_request(claim_id:)

          expect(result).to respond_to(:status)
          expect(result).to respond_to(:body)
          expect(result.status).to eq(200)

          response_body = result.body.is_a?(String) ? JSON.parse(result.body) : result.body
          expect(response_body['success']).to be true
          expect(response_body['statusCode']).to eq(200)
          expect(response_body['message']).to eq('Claim submitted successfully.')
          expect(response_body['data']['claimId']).to be_present
          expect(response_body['data']['status']).to eq('ClaimSubmitted')
          expect(response_body['data']['createdOn']).to be_present
          expect(response_body['data']['modifiedOn']).to be_present
          expect(response_body['correlationId']).to be_present
        end
      end
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

  describe '#send_claim_request' do
    let(:appointment_id) { 'appt-123' }

    before do
      allow(client.redis_client).to receive(:token).and_return('fake_veis_token_123')
      client.instance_variable_set(:@current_veis_token, 'fake_veis_token_123')
      client.instance_variable_set(:@current_btsss_token, 'fake_btsss_token_456')
    end

    it 'makes claim request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/claims_create_200') do
          result = client.send_claim_request(appointment_id:)

          expect(result).to respond_to(:status)
          expect(result).to respond_to(:body)
          expect(result.status).to eq(200)

          response_body = result.body.is_a?(String) ? JSON.parse(result.body) : result.body
          expect(response_body['success']).to be true
          expect(response_body['statusCode']).to eq(200)
          expect(response_body['message']).to eq('Claim created successfully.')
          expect(response_body['data']['claimId']).to be_present
          expect(response_body['correlationId']).to be_present
        end
      end
    end

    context 'when claim creation fails' do
      it 'raises BackendServiceException for invalid appointment ID' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2: 'https://dev.integration.d365.va.gov') do
          VCR.use_cassette('check_in/travel_claim/claims_create_400_duplicate') do
            expect do
              client.send_claim_request(appointment_id: 'duplicate-appt-id')
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end

  describe '#send_get_claim_request' do
    let(:claim_id) { 'claim-123' }

    before do
      allow(client.redis_client).to receive(:token).and_return('fake_veis_token_123')
      client.instance_variable_set(:@current_veis_token, 'fake_veis_token_123')
      client.instance_variable_set(:@current_btsss_token, 'fake_btsss_token_456')
    end

    it 'makes get claim request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/claims_get_200') do
          result = client.send_get_claim_request(claim_id:)

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
                      claims_url_v2: 'https://dev.integration.d365.va.gov') do
          VCR.use_cassette('check_in/travel_claim/claims_get_404') do
            expect do
              client.send_get_claim_request(claim_id: 'non-existent-claim')
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end

    context 'when server error occurs' do
      it 'raises BackendServiceException for 500 response' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2: 'https://dev.integration.d365.va.gov') do
          VCR.use_cassette('check_in/travel_claim/claims_get_500') do
            expect do
              client.send_get_claim_request(claim_id:)
            end.to raise_error(Common::Exceptions::BackendServiceException)
          end
        end
      end
    end
  end

  describe '#send_mileage_expense_request' do
    let(:claim_id) { 'claim-123' }
    let(:date_incurred) { '2024-01-15' }

    before do
      allow(client.redis_client).to receive(:token).and_return('fake_veis_token_123')
      client.instance_variable_set(:@current_veis_token, 'fake_veis_token_123')
      client.instance_variable_set(:@current_btsss_token, 'fake_btsss_token_456')
    end

    it 'makes mileage expense request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/expenses_mileage_200') do
          result = client.send_mileage_expense_request(
            claim_id:,
            date_incurred:
          )

          expect(result).to respond_to(:status)
          expect(result).to respond_to(:body)
          expect(result.status).to eq(200)

          response_body = result.body.is_a?(String) ? JSON.parse(result.body) : result.body
          expect(response_body['success']).to be true
          expect(response_body['statusCode']).to eq(200)
          expect(response_body['message']).to eq('Expense added successfully.')
          expect(response_body['data']['expenseId']).to be_present
          expect(response_body['correlationId']).to be_present
        end
      end
    end
  end

  describe '#send_claim_submission_request' do
    let(:claim_id) { 'claim-123' }

    before do
      allow(client.redis_client).to receive(:token).and_return('fake_veis_token_123')
      client.instance_variable_set(:@current_veis_token, 'fake_veis_token_123')
      client.instance_variable_set(:@current_btsss_token, 'fake_btsss_token_456')
    end

    it 'makes claim submission request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/claims_submit_200') do
          result = client.send_claim_submission_request(claim_id:)

          expect(result).to respond_to(:status)
          expect(result).to respond_to(:body)
          expect(result.status).to eq(200)

          response_body = result.body.is_a?(String) ? JSON.parse(result.body) : result.body
          expect(response_body['success']).to be true
          expect(response_body['statusCode']).to eq(200)
          expect(response_body['message']).to eq('Claim submitted successfully.')
          expect(response_body['data']['claimId']).to be_present
          expect(response_body['data']['status']).to eq('ClaimSubmitted')
          expect(response_body['data']['createdOn']).to be_present
          expect(response_body['data']['modifiedOn']).to be_present
          expect(response_body['correlationId']).to be_present
        end
      end
    end
  end

  describe '#config' do
    it 'returns the TravelClaim::Configuration instance' do
      expect(client.config).to eq(TravelClaim::Configuration.instance)
    end
  end

  describe 'initialization' do
    it 'raises error when UUID is blank' do
      expect { described_class.new(uuid: '', appointment_date_time:) }
        .to raise_error(ArgumentError, 'UUID cannot be blank')
    end
  end

  describe 'authentication' do
    it 'handles 401 errors by refreshing tokens and retrying once' do
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

    it 'fails fast when token refresh fails after 401' do
      # Set up tokens
      client.instance_variable_set(:@current_veis_token, 'test-veis-token')
      client.instance_variable_set(:@current_btsss_token, 'test-btsss-token')

      # First call raises 401, token refresh fails
      allow(client).to receive(:perform).and_raise(
        Common::Exceptions::BackendServiceException.new('TEST', {}, 401, 'Unauthorized')
      )
      allow(client).to receive(:refresh_tokens!).and_raise(
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
      client.instance_variable_set(:@current_veis_token, 'test-veis-token')
      client.instance_variable_set(:@current_btsss_token, 'test-btsss-token')

      # Multiple 401 responses should only trigger one retry
      allow(client).to receive(:perform).and_raise(
        Common::Exceptions::BackendServiceException.new('TEST', {}, 401, 'Unauthorized')
      )
      expect(client).to receive(:refresh_tokens!).once

      expect do
        client.send(:with_auth) do
          client.send(:perform, :get, '/test', {}, {})
        end
      end.to raise_error(Common::Exceptions::BackendServiceException)
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

      headers = client.send(:headers)

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
      with_settings(Settings, vsp_environment: 'dev') do
        with_settings(Settings.check_in.travel_reimbursement_api_v2, subscription_key: 'sub-key') do
          headers = client.subscription_key_headers
          expect(headers).to eq({ 'Ocp-Apim-Subscription-Key' => 'sub-key' })
        end
      end
      expect(client).to receive(:refresh_tokens!)

    it 'returns separate E and S keys for production environment' do
      with_settings(Settings, vsp_environment: 'production') do
        with_settings(Settings.check_in.travel_reimbursement_api_v2, e_subscription_key: 'e-sub',
                                                                     s_subscription_key: 's-sub') do
          headers = client.subscription_key_headers
          expect(headers).to eq({
                                  'Ocp-Apim-Subscription-Key-E' => 'e-sub',
                                  'Ocp-Apim-Subscription-Key-S' => 's-sub'
                                })
        end
      end
    end
  end

  describe '#patch method override' do
    before do
      allow(client.redis_client).to receive(:token).and_return('fake_veis_token_123')
      client.instance_variable_set(:@current_veis_token, 'fake_veis_token_123')
      client.instance_variable_set(:@current_btsss_token, 'fake_btsss_token_456')
    end

    it 'calls request method directly for PATCH requests' do
      expect(client).to receive(:request).with(:patch, anything, anything, anything, anything)

      client.send(:perform, :patch, '/test/patch', {}, {})
    end

    it 'successfully makes PATCH requests for claim submission' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://dev.integration.d365.va.gov') do
        VCR.use_cassette('check_in/travel_claim/claims_submit_200') do
          result = client.send_claim_submission_request(claim_id: 'test-claim-id')

          expect(result).to respond_to(:status)
          expect(result.status).to eq(200)
        end
      end
    end
  end
end
