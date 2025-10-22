# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe TravelClaim::TravelPayClient do
  let(:check_in_uuid) { 'test-uuid-123' }
  let(:appointment_date_time) { '2024-01-01T12:00:00Z' }
  let(:redis_client) { instance_double(TravelClaim::RedisClient) }
  let(:client) { described_class.new(check_in_uuid:, appointment_date_time:) }

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
    # Both ICN and station_number are retrieved using the same uuid
    allow(redis_client).to receive(:icn).with(uuid: check_in_uuid).and_return(test_icn)
    allow(redis_client).to receive(:station_number).with(uuid: check_in_uuid).and_return(test_station_number)
  end

  # Settings are configured in individual tests using with_settings

  describe '#load_redis_data' do
    context 'when Redis operations succeed' do
      it 'loads ICN and station number successfully' do
        expect(redis_client).to receive(:icn).with(uuid: check_in_uuid).and_return(test_icn)
        expect(redis_client).to receive(:station_number).with(uuid: check_in_uuid).and_return(test_station_number)

        client = described_class.new(check_in_uuid:, appointment_date_time:)

        expect(client.instance_variable_get(:@icn)).to eq(test_icn)
        expect(client.instance_variable_get(:@station_number)).to eq(test_station_number)
      end
    end

    context 'when Redis ICN lookup fails' do
      it 'raises ArgumentError with clear error message' do
        allow(redis_client).to receive(:icn).with(uuid: check_in_uuid)
                                            .and_raise(Redis::ConnectionError, 'Connection refused')

        expect do
          described_class.new(check_in_uuid:, appointment_date_time:)
        end.to raise_error(ArgumentError,
                           "Failed to load data from Redis for check-in UUID #{check_in_uuid}")
      end
    end

    context 'when Redis station number lookup fails' do
      it 'raises ArgumentError with clear error message' do
        allow(redis_client).to receive(:icn).with(uuid: check_in_uuid).and_return(test_icn)
        allow(redis_client).to receive(:station_number).with(uuid: check_in_uuid).and_raise(Redis::TimeoutError,
                                                                                            'Operation timed out')

        expect do
          described_class.new(check_in_uuid:, appointment_date_time:)
        end.to raise_error(ArgumentError,
                           "Failed to load data from Redis for check-in UUID #{check_in_uuid}")
      end
    end

    context 'when Redis returns nil values' do
      it 'raises ArgumentError with clear error message' do
        allow(redis_client).to receive(:icn).with(uuid: check_in_uuid).and_return(nil)
        allow(redis_client).to receive(:station_number).with(uuid: check_in_uuid).and_return(nil)

        expect do
          described_class.new(check_in_uuid:, appointment_date_time:)
        end.to raise_error(ArgumentError, 'Missing required arguments: ICN, station number')
      end
    end

    context 'when Redis client is unavailable' do
      it 'raises ArgumentError with clear error message' do
        allow(TravelClaim::RedisClient).to receive(:build).and_raise(StandardError, 'Redis server not available')

        expect do
          described_class.new(check_in_uuid:, appointment_date_time:)
        end.to raise_error(StandardError, 'Redis server not available')
      end
    end
  end

  describe '#veis_token_request' do
    it 'makes VEIS token request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    auth_url:,
                    tenant_id:,
                    travel_pay_client_id:,
                    travel_pay_client_secret:,
                    scope:,
                    travel_pay_resource:) do
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
    it 'makes system access token request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
        VCR.use_cassette('check_in/travel_claim/system_access_token_200') do
          result = client.send(:system_access_token_request,
                               veis_access_token: 'test-veis-token',
                               icn: test_icn)

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
      allow(client.redis_client).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'makes appointment request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
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
                      claims_url_v2:) do
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
    let(:appointment_id) { test_appointment_id }

    before do
      allow(client.redis_client).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'makes claim request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
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
                      claims_url_v2:) do
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
    let(:claim_id) { test_claim_id }

    before do
      allow(client.redis_client).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'makes get claim request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
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
                      claims_url_v2:) do
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
                      claims_url_v2:) do
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
    let(:claim_id) { test_claim_id }
    let(:date_incurred) { test_date_incurred }

    before do
      allow(client.redis_client).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'makes mileage expense request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
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
    let(:claim_id) { test_claim_id }

    before do
      allow(client.redis_client).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
    end

    it 'makes claim submission request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:) do
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
    let(:test_veis_token_for_headers) { 'test-veis-token' }
    let(:test_btsss_token_for_headers) { 'test-btsss-token' }
    let(:new_veis_token) { 'new-veis-token' }
    let(:new_btsss_token) { 'new-btsss-token' }

    before do
      client.instance_variable_set(:@current_veis_token, test_veis_token_for_headers)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token_for_headers)
    end

    it 'rebuilds headers when tokens change' do
      initial_headers = client.send(:headers)

      # Change tokens
      client.instance_variable_set(:@current_veis_token, new_veis_token)
      client.instance_variable_set(:@current_btsss_token, new_btsss_token)

      # Clear memoized headers
      client.instance_variable_set(:@headers, nil)

      new_headers = client.send(:headers)

      expect(new_headers).not_to eq(initial_headers)
      expect(new_headers['Authorization']).to eq("Bearer #{new_veis_token}")
      expect(new_headers['BTSSS-Access-Token']).to eq(new_btsss_token)
    end

    it 'includes all required headers' do
      headers = client.send(:headers)

      expect(headers).to include(
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{test_veis_token_for_headers}",
        'BTSSS-Access-Token' => test_btsss_token_for_headers,
        'X-Correlation-ID' => client.instance_variable_get(:@correlation_id)
      )
    end

    it 'includes subscription key headers' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2, subscription_key:) do
        headers = client.send(:headers)
        expect(headers).to include('Ocp-Apim-Subscription-Key' => subscription_key)
      end
    end
  end

  describe '#config' do
    it 'returns the TravelClaim::Configuration instance' do
      expect(client.config).to eq(TravelClaim::Configuration.instance)
    end
  end

  describe 'initialization' do
    context 'with check_in_uuid' do
      it 'raises error when appointment_date_time is blank' do
        expect { described_class.new(check_in_uuid:, appointment_date_time: '') }
          .to raise_error(ArgumentError, /appointment date time/)
      end

      it 'accepts check_in_uuid and appointment_date_time parameters' do
        expect { described_class.new(check_in_uuid:, appointment_date_time:) }
          .not_to raise_error
      end

      it 'loads ICN and station_number from Redis when not provided' do
        expect(redis_client).to receive(:icn).with(uuid: check_in_uuid).and_return(test_icn)
        expect(redis_client).to receive(:station_number).with(uuid: check_in_uuid).and_return(test_station_number)

        client = described_class.new(check_in_uuid:, appointment_date_time:)

        expect(client.instance_variable_get(:@icn)).to eq(test_icn)
        expect(client.instance_variable_get(:@station_number)).to eq(test_station_number)
      end

      it 'raises error when check_in_uuid is blank and ICN/station_number not provided' do
        expect { described_class.new(check_in_uuid: '', appointment_date_time:) }
          .to raise_error(ArgumentError, /check-in UUID/)
      end
    end

    context 'with direct ICN and station_number' do
      it 'accepts icn, station_number, and appointment_date_time without check_in_uuid' do
        expect(TravelClaim::RedisClient).not_to receive(:build)

        client = described_class.new(
          appointment_date_time:,
          icn: test_icn,
          station_number: test_station_number
        )

        expect(client.instance_variable_get(:@icn)).to eq(test_icn)
        expect(client.instance_variable_get(:@station_number)).to eq(test_station_number)
        expect(client.instance_variable_get(:@redis_client)).to be_nil
      end

      it 'raises error when only ICN is provided without station_number or check_in_uuid' do
        expect do
          described_class.new(
            appointment_date_time:,
            icn: test_icn
          )
        end.to raise_error(ArgumentError, /station number/)
      end

      it 'raises error when only station_number is provided without ICN or check_in_uuid' do
        expect do
          described_class.new(
            appointment_date_time:,
            station_number: test_station_number
          )
        end.to raise_error(ArgumentError, /ICN/)
      end

      it 'loads missing station_number from Redis when only ICN is provided with check_in_uuid' do
        # When ICN is provided, only station_number should be loaded from Redis
        expect(redis_client).to receive(:station_number).with(uuid: check_in_uuid).and_return(test_station_number)

        client = described_class.new(
          appointment_date_time:,
          check_in_uuid:,
          icn: test_icn
        )

        expect(client.instance_variable_get(:@icn)).to eq(test_icn)
        expect(client.instance_variable_get(:@station_number)).to eq(test_station_number)
      end

      it 'loads missing ICN from Redis when only station_number is provided with check_in_uuid' do
        # When station_number is provided, only ICN should be loaded from Redis
        expect(redis_client).to receive(:icn).with(uuid: check_in_uuid).and_return(test_icn)

        client = described_class.new(
          appointment_date_time:,
          check_in_uuid:,
          station_number: test_station_number
        )

        expect(client.instance_variable_get(:@icn)).to eq(test_icn)
        expect(client.instance_variable_get(:@station_number)).to eq(test_station_number)
      end

      it 'does not override provided ICN and station_number with Redis values' do
        provided_icn = 'provided_icn_123'
        provided_station = 'provided_station_456'

        expect(TravelClaim::RedisClient).not_to receive(:build)

        client = described_class.new(
          appointment_date_time:,
          icn: provided_icn,
          station_number: provided_station
        )

        expect(client.instance_variable_get(:@icn)).to eq(provided_icn)
        expect(client.instance_variable_get(:@station_number)).to eq(provided_station)
      end
    end

    context 'error reporting' do
      it 'reports all missing arguments at once' do
        error_raised = nil

        begin
          described_class.new(appointment_date_time: '')
        rescue ArgumentError => e
          error_raised = e
        end

        expect(error_raised).to be_present
        expect(error_raised.message).to include('appointment date time')
        expect(error_raised.message).to include('ICN')
        expect(error_raised.message).to include('station number')
        expect(error_raised.message).to include('check-in UUID')
      end
    end
  end

  describe 'authentication' do
    context 'with Redis client' do
      it 'handles 401 errors by refreshing tokens and retrying once' do
        # Set up tokens
        client.instance_variable_set(:@current_veis_token, test_veis_token)
        client.instance_variable_set(:@current_btsss_token, test_btsss_token)
        allow(client.redis_client).to receive(:token).and_return(test_veis_token)
        allow(client.redis_client).to receive(:save_token).with(token: test_veis_token)

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
        client.instance_variable_set(:@current_veis_token, test_veis_token)
        client.instance_variable_set(:@current_btsss_token, test_btsss_token)
        allow(client.redis_client).to receive(:token).and_return(test_veis_token)
        allow(client.redis_client).to receive(:save_token).with(token: test_veis_token)

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
        client.instance_variable_set(:@current_veis_token, test_veis_token)
        client.instance_variable_set(:@current_btsss_token, test_btsss_token)
        allow(client.redis_client).to receive(:token).and_return(test_veis_token)
        allow(client.redis_client).to receive(:save_token).with(token: test_veis_token)

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

      it 'logs auth retry when 401 error occurs' do
        # Mock Rails.logger to capture log calls
        allow(Rails.logger).to receive(:error)

        # Set up tokens
        client.instance_variable_set(:@current_veis_token, test_veis_token)
        client.instance_variable_set(:@current_btsss_token, test_btsss_token)
        allow(client.redis_client).to receive(:token).and_return(test_veis_token)
        allow(client.redis_client).to receive(:save_token).with(token: test_veis_token)

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

        # Mock the refresh_tokens! method to simulate successful token refresh
        allow(client).to receive(:refresh_tokens!) do
          client.instance_variable_set(:@current_veis_token, 'new-veis-token')
          client.instance_variable_set(:@current_btsss_token, 'new-btsss-token')
        end

        client.send(:with_auth) do
          client.send(:perform, :get, '/test', {}, {})
        end

        # Verify that the auth retry log was called
        expect(Rails.logger).to have_received(:error).with(
          'TravelPayClient 401 error - retrying authentication',
          hash_including(
            correlation_id: be_present,
            check_in_uuid:,
            veis_token_present: true,
            btsss_token_present: true
          )
        )
      end

      it 'uses cached VEIS token from Redis when available' do
        cached_veis_token = 'cached-veis'
        allow(client.redis_client).to receive(:token).and_return(cached_veis_token)
        allow(client.redis_client).to receive(:save_token).with(token: cached_veis_token)
        expect(client).to receive(:btsss_token!)

        client.send(:ensure_tokens!)

        expect(client.instance_variable_get(:@current_veis_token)).to eq(cached_veis_token)
      end

      it 'builds headers with current tokens' do
        test_veis = 'test-veis'
        test_btsss = 'test-btsss'
        client.instance_variable_set(:@current_veis_token, test_veis)
        client.instance_variable_set(:@current_btsss_token, test_btsss)

        headers = client.send(:headers)

        expect(headers['Authorization']).to eq("Bearer #{test_veis}")
        expect(headers['BTSSS-Access-Token']).to eq(test_btsss)
        expect(headers['X-Correlation-ID']).to eq(client.instance_variable_get(:@correlation_id))
      end

      it 'fetches fresh tokens when none are cached' do
        allow(client.redis_client).to receive(:token).and_return(nil)
        allow(client).to receive(:veis_token_request)
          .and_return(double('Response', body: { 'access_token' => 'new-token' }))
        allow(client.redis_client).to receive(:save_token).with(token: 'new-token')
        expect(client).to receive(:btsss_token!)

        client.send(:ensure_tokens!)
      end

      it 'refreshes tokens and clears cache' do
        old_veis_token = 'old-veis'
        old_btsss_token = 'old-btsss'
        client.instance_variable_set(:@current_veis_token, old_veis_token)
        client.instance_variable_set(:@current_btsss_token, old_btsss_token)
        allow(client.redis_client).to receive(:save_token).with(token: nil)
        allow(client.redis_client).to receive(:token).and_return(nil)
        allow(client).to receive(:veis_token_request)
          .and_return(double('Response', body: { 'access_token' => 'new-token' }))
        allow(client.redis_client).to receive(:save_token).with(token: 'new-token')
        allow(client).to receive(:system_access_token_request) do
          client.instance_variable_set(:@current_btsss_token, 'new-btsss-token')
          double('Response', body: { 'data' => { 'accessToken' => 'new-btsss-token' } })
        end

        client.send(:refresh_tokens!)

        # After refresh, tokens should be cleared initially, then new ones fetched
        expect(client.instance_variable_get(:@current_veis_token)).to eq('new-token')
        expect(client.instance_variable_get(:@current_btsss_token)).to eq('new-btsss-token')
      end
    end

    context 'with direct ICN and station_number (lazy Redis initialization)' do
      let(:direct_client) do
        described_class.new(
          appointment_date_time:,
          icn: test_icn,
          station_number: test_station_number
        )
      end

      it 'does not initialize Redis client during validation when ICN and station_number provided' do
        expect(direct_client.instance_variable_get(:@redis_client)).to be_nil
      end

      it 'lazily initializes Redis client when needed for token caching' do
        # Mock the Redis client that will be lazily created
        lazy_redis_client = instance_double(TravelClaim::RedisClient)
        allow(TravelClaim::RedisClient).to receive(:build).and_return(lazy_redis_client)
        allow(lazy_redis_client).to receive(:token).and_return(nil)
        allow(lazy_redis_client).to receive(:save_token)

        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      auth_url:,
                      tenant_id:,
                      travel_pay_client_id:,
                      travel_pay_client_secret:,
                      scope:,
                      travel_pay_resource:) do
          VCR.use_cassette('check_in/travel_claim/veis_token_200') do
            # Redis client should be nil before token operations
            expect(direct_client.instance_variable_get(:@redis_client)).to be_nil

            direct_client.send(:veis_token!)

            # Redis client should be initialized after token operations
            expect(direct_client.instance_variable_get(:@redis_client)).to be_present
            expect(direct_client.instance_variable_get(:@current_veis_token)).to be_present
          end
        end
      end

      it 'handles token refresh with lazy Redis initialization' do
        veis_response = double('Response', body: { 'access_token' => 'new-token' })
        btsss_response = double('Response', body: { 'data' => { 'accessToken' => 'new-btsss' } })

        # Mock the Redis client that will be lazily created
        lazy_redis_client = instance_double(TravelClaim::RedisClient)
        allow(TravelClaim::RedisClient).to receive(:build).and_return(lazy_redis_client)
        allow(lazy_redis_client).to receive(:token).and_return(nil)
        allow(lazy_redis_client).to receive(:save_token)

        allow(direct_client).to receive_messages(
          veis_token_request: veis_response,
          system_access_token_request: btsss_response
        )

        direct_client.send(:refresh_tokens!)

        expect(direct_client.instance_variable_get(:@current_veis_token)).to eq('new-token')
        expect(direct_client.instance_variable_get(:@current_btsss_token)).to eq('new-btsss')
      end
    end
  end

  describe '#subscription_key_headers' do
    it 'returns single subscription key for non-production environments' do
      with_settings(Settings, vsp_environment: 'dev') do
        with_settings(Settings.check_in.travel_reimbursement_api_v2, subscription_key:) do
          headers = client.subscription_key_headers
          expect(headers).to eq({ 'Ocp-Apim-Subscription-Key' => subscription_key })
        end
      end
    end

    it 'returns separate E and S keys for production environment' do
      with_settings(Settings, vsp_environment: 'production') do
        with_settings(Settings.check_in.travel_reimbursement_api_v2, e_subscription_key:,
                                                                     s_subscription_key:) do
          headers = client.subscription_key_headers
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
      allow(client.redis_client).to receive(:token).and_return(test_veis_token)
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
          result = client.send_claim_submission_request(claim_id: test_claim_id)

          expect(result).to respond_to(:status)
          expect(result.status).to eq(200)
        end
      end
    end
  end
end
