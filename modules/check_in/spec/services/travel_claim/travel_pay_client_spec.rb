# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TravelClaim::TravelPayClient do
  let(:icn) { '1234567890V123456' }
  let(:client) { described_class.new(icn:) }

  # Settings are configured in individual tests using with_settings

  describe '#veis_token_request' do
    it 'makes VEIS token request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    auth_url: 'https://auth.example.test',
                    tenant_id: 'tenant-123',
                    travel_pay_client_id: 'client-id',
                    travel_pay_client_secret: 'super-secret-123',
                    scope: 'scope.read',
                    travel_pay_resource: 'test-resource') do
        mock_response = double('Response', body: { 'access_token' => 'test-token' })

        expect(client).to receive(:perform).with(
          :post,
          'https://auth.example.test/tenant-123/oauth2/token',
          'client_id=client-id&client_secret=super-secret-123&client_type=1&' \
          'scope=scope.read&grant_type=client_credentials&resource=test-resource',
          { 'Content-Type' => 'application/x-www-form-urlencoded' }
        ).and_return(mock_response)

        result = client.veis_token_request
        expect(result).to eq(mock_response)
      end
    end
  end

  describe '#system_access_token_request' do
    let(:client_number) { 'test-client-123' }
    let(:veis_access_token) { 'veis-token-abc' }

    it 'makes system access token request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://claims.example.test',
                    travel_pay_client_secret: 'super-secret-123') do
        mock_response = double('Response', body: { 'data' => { 'accessToken' => 'v4-token' } })

        expect(client).to receive(:perform).with(
          :post,
          'https://claims.example.test/api/v4/auth/system-access-token',
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
  end

  describe '#send_appointment_request' do
    let(:appointment_date_time) { '2024-01-15T10:00:00Z' }
    let(:facility_id) { 'facility-123' }

    before do
      # Mock ensure_tokens! to skip token fetching
      allow(client).to receive(:ensure_tokens!)
      # Mock the headers method to return expected headers
      allow(client).to receive(:headers).and_return({
                                                      'Content-Type' => 'application/json',
                                                      'Authorization' => 'Bearer test-veis-token',
                                                      'X-BTSSS-Token' => 'test-btsss-token',
                                                      'X-Correlation-ID' =>
                                                        client.instance_variable_get(:@correlation_id)
                                                    })
    end

    it 'makes appointment request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2: 'https://claims.example.test') do
        mock_response = double('Response', body: { 'data' => { 'id' => 'appt-123' } })

        expect(client).to receive(:perform).with(
          :post,
          'https://claims.example.test/api/v3/appointments/find-or-add',
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
  end

  describe '#send_claim_request' do
    let(:appointment_id) { 'appt-123' }

    before do
      # Mock ensure_tokens! to skip token fetching
      allow(client).to receive(:ensure_tokens!)
      # Mock the headers method to return expected headers
      allow(client).to receive(:headers).and_return({
                                                      'Content-Type' => 'application/json',
                                                      'Authorization' => 'Bearer test-veis-token',
                                                      'X-BTSSS-Token' => 'test-btsss-token',
                                                      'X-Correlation-ID' =>
                                                        client.instance_variable_get(:@correlation_id)
                                                    })
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
  end

  describe '#send_mileage_expense_request' do
    let(:claim_id) { 'claim-123' }
    let(:date_incurred) { '2024-01-15' }

    before do
      # Mock ensure_tokens! to skip token fetching
      allow(client).to receive(:ensure_tokens!)
      # Mock the headers method to return expected headers
      allow(client).to receive(:headers).and_return({
                                                      'Content-Type' => 'application/json',
                                                      'Authorization' => 'Bearer test-veis-token',
                                                      'X-BTSSS-Token' => 'test-btsss-token',
                                                      'X-Correlation-ID' =>
                                                        client.instance_variable_get(:@correlation_id)
                                                    })
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
      # Mock ensure_tokens! to skip token fetching
      allow(client).to receive(:ensure_tokens!)
      # Mock the headers method to return expected headers
      allow(client).to receive(:headers).and_return({
                                                      'Content-Type' => 'application/json',
                                                      'Authorization' => 'Bearer test-veis-token',
                                                      'X-BTSSS-Token' => 'test-btsss-token',
                                                      'X-Correlation-ID' =>
                                                        client.instance_variable_get(:@correlation_id)
                                                    })
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
          expect(response_body['data']['status']).to eq('InManualReview')
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
    end

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
end
