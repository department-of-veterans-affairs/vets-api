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
  let(:travel_pay_client_secret_oh) { 'fake_client_secret_oh' }
  let(:travel_pay_resource) { 'fake_resource' }
  let(:claims_url_v2) { 'https://dev.integration.d365.va.gov' }
  let(:claims_base_path_v2) { 'eis/api/btsss/travelclaim' }
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
      it 'catches Redis error and reports missing arguments with Redis context' do
        allow(redis_client).to receive(:icn).with(uuid: check_in_uuid)
                                            .and_raise(Redis::ConnectionError, 'Connection refused')

        expect do
          described_class.new(check_in_uuid:, appointment_date_time:)
        end.to raise_error(TravelClaim::Errors::InvalidArgument,
                           'Missing required arguments: ICN, station number, ' \
                           'data from Redis (check-in UUID provided but Redis unavailable)')
      end
    end

    context 'when Redis station number lookup fails' do
      it 'catches Redis error and reports missing arguments with Redis context' do
        allow(redis_client).to receive(:icn).with(uuid: check_in_uuid).and_return(test_icn)
        allow(redis_client).to receive(:station_number).with(uuid: check_in_uuid).and_raise(Redis::TimeoutError,
                                                                                            'Operation timed out')

        expect do
          described_class.new(check_in_uuid:, appointment_date_time:)
        end.to raise_error(TravelClaim::Errors::InvalidArgument,
                           'Missing required arguments: station number, ' \
                           'data from Redis (check-in UUID provided but Redis unavailable)')
      end
    end

    context 'when Redis returns nil values' do
      it 'raises InvalidArgument with clear error message' do
        allow(redis_client).to receive(:icn).with(uuid: check_in_uuid).and_return(nil)
        allow(redis_client).to receive(:station_number).with(uuid: check_in_uuid).and_return(nil)

        expect do
          described_class.new(check_in_uuid:, appointment_date_time:)
        end.to raise_error(TravelClaim::Errors::InvalidArgument, 'Missing required arguments: ICN, station number')
      end
    end

    context 'when Redis client is unavailable' do
      it 'raises StandardError when Redis client cannot be built' do
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

    context 'when request fails' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error when GatewayTimeout is raised' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          allow(client).to receive(:perform).and_raise(
            Common::Exceptions::GatewayTimeout.new('Timeout::Error')
          )

          expect do
            client.send(:veis_token_request)
          end.to raise_error(Common::Exceptions::GatewayTimeout)

          expect(Rails.logger).to have_received(:error).with(
            hash_including(
              message: 'TravelPayClient: VEIS API Error',
              endpoint: 'VEIS',
              operation: 'veis_token_request',
              correlation_id: be_present,
              http_status: 504,
              error_class: 'Common::Exceptions::GatewayTimeout'
            )
          )
        end
      end
    end
  end

  describe '#system_access_token_request' do
    it 'makes system access token request with correct parameters' do
      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:, claims_base_path_v2:) do
        VCR.use_cassette('check_in/travel_claim/system_access_token_200') do
          result = client.send(:system_access_token_request,
                               veis_access_token: 'test-veis-token',
                               icn: test_icn)

          expect(result).to respond_to(:status)
          expect(result.status).to eq(200)
        end
      end
    end

    context 'when request fails' do
      before do
        allow(Rails.logger).to receive(:error)
      end

      it 'logs error when BackendServiceException is raised' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          allow(client).to receive(:perform).and_raise(
            Common::Exceptions::BackendServiceException.new('TEST', {}, 500, 'Internal Server Error')
          )

          expect do
            client.send(:system_access_token_request,
                        veis_access_token: 'test-veis-token',
                        icn: test_icn)
          end.to raise_error(Common::Exceptions::BackendServiceException)

          expect(Rails.logger).to have_received(:error).with(
            hash_including(
              message: 'TravelPayClient: BTSSS API Error',
              endpoint: 'BTSSS',
              operation: 'system_access_token_request',
              correlation_id: be_present,
              http_status: 500,
              error_class: 'Common::Exceptions::BackendServiceException',
              error_code: 'TEST'
            )
          )
        end
      end

      it 'logs error when 502 Bad Gateway error occurs' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          allow(client).to receive(:perform).and_raise(
            Common::Exceptions::BackendServiceException.new('VA900', {}, 502, 'Bad Gateway')
          )

          expect do
            client.send(:system_access_token_request,
                        veis_access_token: 'test-veis-token',
                        icn: test_icn)
          end.to raise_error(Common::Exceptions::BackendServiceException)

          expect(Rails.logger).to have_received(:error).with(
            hash_including(
              message: 'TravelPayClient: BTSSS API Error',
              endpoint: 'BTSSS',
              operation: 'system_access_token_request',
              correlation_id: be_present,
              http_status: 502,
              error_class: 'Common::Exceptions::BackendServiceException',
              error_code: 'VA900'
            )
          )
        end
      end

      it 'logs error when ClientError is raised' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          allow(client).to receive(:perform).and_raise(
            Common::Client::Errors::ClientError.new('Connection failed', 503)
          )

          expect do
            client.send(:system_access_token_request,
                        veis_access_token: 'test-veis-token',
                        icn: test_icn)
          end.to raise_error(Common::Client::Errors::ClientError)

          expect(Rails.logger).to have_received(:error).with(
            hash_including(
              message: 'TravelPayClient: BTSSS API Error',
              endpoint: 'BTSSS',
              operation: 'system_access_token_request',
              correlation_id: be_present,
              http_status: 503,
              error_class: 'Common::Client::Errors::ClientError'
            )
          )
        end
      end

      it 'logs error when GatewayTimeout is raised' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          allow(client).to receive(:perform).and_raise(
            Common::Exceptions::GatewayTimeout.new('Timeout::Error')
          )

          expect do
            client.send(:system_access_token_request,
                        veis_access_token: 'test-veis-token',
                        icn: test_icn)
          end.to raise_error(Common::Exceptions::GatewayTimeout)

          expect(Rails.logger).to have_received(:error).with(
            hash_including(
              message: 'TravelPayClient: BTSSS API Error',
              endpoint: 'BTSSS',
              operation: 'system_access_token_request',
              correlation_id: be_present,
              http_status: 504,
              error_class: 'Common::Exceptions::GatewayTimeout'
            )
          )
        end
      end

      it 'logs original_status (downstream HTTP status) instead of transformed status' do
        allow(Flipper).to receive(:enabled?)
          .with(:check_in_experience_travel_claim_log_api_error_details).and_return(true)

        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:) do
          # Simulate a 405 Method Not Allowed from downstream API
          # BackendServiceException will transform this to 502 (VA900) for API responses,
          # but we want to log the original 405
          error_body = { 'message' => 'Method not allowed' }.to_json
          exception = Common::Exceptions::BackendServiceException.new('VA900', {}, 405, error_body)
          allow(client).to receive(:perform).and_raise(exception)

          expect do
            client.send(:system_access_token_request,
                        veis_access_token: 'test-veis-token',
                        icn: test_icn)
          end.to raise_error(Common::Exceptions::BackendServiceException)

          # Verify we log the original_status (405), not the transformed status (502)
          expect(Rails.logger).to have_received(:error).with(
            hash_including(
              message: 'TravelPayClient: BTSSS API Error',
              endpoint: 'BTSSS',
              operation: 'system_access_token_request',
              correlation_id: be_present,
              http_status: 405, # original_status, not the transformed status
              error_class: 'Common::Exceptions::BackendServiceException',
              error_code: 'VA900',
              api_error_message: 'Method not allowed'
            )
          )
        end
      end
    end
  end

  describe '#extract_and_redact_message' do
    it 'removes ICN from error message using DataScrubber' do
      icn = '1234567890V123456'
      body = { 'message' => "Error occurred for patient #{icn}" }.to_json
      result = client.send(:extract_and_redact_message, body)

      expect(result).to eq('Error occurred for patient [REDACTED]')
      expect(result).not_to include(icn)
    end

    it 'returns nil when body is nil' do
      result = client.send(:extract_and_redact_message, nil)
      expect(result).to be_nil
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
                    claims_url_v2:, claims_base_path_v2:) do
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
                      claims_url_v2:, claims_base_path_v2:) do
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
                    claims_url_v2:, claims_base_path_v2:) do
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
                      claims_url_v2:, claims_base_path_v2:) do
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
                    claims_url_v2:, claims_base_path_v2:) do
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
                      claims_url_v2:, claims_base_path_v2:) do
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
                      claims_url_v2:, claims_base_path_v2:) do
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
                    claims_url_v2:, claims_base_path_v2:) do
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
                    claims_url_v2:, claims_base_path_v2:) do
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
          .to raise_error(TravelClaim::Errors::InvalidArgument, /appointment date time/)
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
          .to raise_error(TravelClaim::Errors::InvalidArgument, /check-in UUID/)
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
        end.to raise_error(TravelClaim::Errors::InvalidArgument, /station number/)
      end

      it 'raises error when only station_number is provided without ICN or check_in_uuid' do
        expect do
          described_class.new(
            appointment_date_time:,
            station_number: test_station_number
          )
        end.to raise_error(TravelClaim::Errors::InvalidArgument, /ICN/)
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
        rescue TravelClaim::Errors::InvalidArgument => e
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
      it 'retries once on 401 by refreshing tokens from cache' do
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
            double('Response', status: 200, success?: true)
          end
        end

        # Mock ensure_tokens! to set fresh tokens on retry
        allow(client).to receive(:ensure_tokens!) do
          if client.instance_variable_get(:@current_veis_token).nil?
            client.instance_variable_set(:@current_veis_token, 'refreshed-veis-token')
            client.instance_variable_set(:@current_btsss_token, 'refreshed-btsss-token')
          end
        end

        # Should succeed after retry
        result = client.send(:with_auth) do
          client.send(:perform, :get, '/test', {}, {})
        end

        expect(result.status).to eq(200)
        expect(call_count).to eq(2) # Called twice (initial + retry)
      end

      it 'does not retry more than once on 401' do
        # Set up tokens
        client.instance_variable_set(:@current_veis_token, test_veis_token)
        client.instance_variable_set(:@current_btsss_token, test_btsss_token)

        # Always raises 401
        allow(client).to receive(:perform).and_raise(
          Common::Exceptions::BackendServiceException.new('TEST', {}, 401, 'Unauthorized')
        )

        # Mock ensure_tokens! to set tokens
        call_count = 0
        allow(client).to receive(:ensure_tokens!) do
          call_count += 1
          client.instance_variable_set(:@current_veis_token, "token-#{call_count}")
          client.instance_variable_set(:@current_btsss_token, "btsss-#{call_count}")
        end

        # Should raise after one retry
        expect do
          client.send(:with_auth) do
            client.send(:perform, :get, '/test', {}, {})
          end
        end.to raise_error(Common::Exceptions::BackendServiceException)

        # ensure_tokens! should be called twice: initial + one retry
        expect(call_count).to eq(2)
      end

      it 'uses cached VEIS token from Rails.cache when available' do
        cached_veis_token = 'cached-veis'

        # Mock Rails.cache.fetch to return cached token
        allow(Rails.cache).to receive(:fetch).with(
          'token',
          hash_including(namespace: 'check-in-btsss-cache-v1')
        ).and_return(cached_veis_token)

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
        allow(client.redis_client).to receive(:v1_veis_token).and_return(nil)
        allow(client).to receive(:veis_token_request)
          .and_return(double('Response', body: { 'access_token' => 'new-token' }))
        allow(client.redis_client).to receive(:save_v1_veis_token).with(token: 'new-token')
        expect(client).to receive(:btsss_token!)

        client.send(:ensure_tokens!)
      end

      it 'uses Rails.cache.fetch for proactive VEIS token refresh' do
        # Clear instance variable to force cache fetch
        client.instance_variable_set(:@current_veis_token, nil)

        # Mock Rails.cache.fetch to return a token
        expect(Rails.cache).to receive(:fetch).with(
          'token',
          hash_including(
            namespace: 'check-in-btsss-cache-v1',
            expires_in: 54.minutes,
            race_condition_ttl: 5.minutes
          )
        ).and_return('cached-veis-token')

        result = client.send(:veis_token!)

        expect(result).to eq('cached-veis-token')
        expect(client.instance_variable_get(:@current_veis_token)).to eq('cached-veis-token')
      end

      it 'ensures only one process mints token with race_condition_ttl under concurrent load' do
        require 'concurrent'

        # Track mint calls and tokens returned
        mint_count = Concurrent::AtomicFixnum.new(0)
        tokens_returned = Concurrent::Array.new

        # Mock mint_veis_token to track calls
        allow_any_instance_of(described_class).to receive(:mint_veis_token) do
          count = mint_count.increment
          sleep(0.05) # Simulate network latency
          "new-token-#{count}"
        end

        # Pre-populate cache with old token
        old_token = 'old-stale-token'
        allow(Rails.cache).to receive(:fetch).and_call_original

        # Simulate race_condition_ttl behavior where first caller mints, others get old token
        first_call = true
        allow(Rails.cache).to receive(:fetch).with(
          'token',
          hash_including(namespace: 'check-in-btsss-cache-v1')
        ) do |_key, _options, &block|
          if first_call
            first_call = false
            block.call # First thread mints new token
          else
            old_token # Other threads get old token (race_condition_ttl behavior)
          end
        end

        # Spawn 10 concurrent threads
        threads = 10.times.map do
          Thread.new do # rubocop:disable ThreadSafety/NewThread
            client = described_class.new(
              appointment_date_time:,
              icn: test_icn,
              station_number: test_station_number
            )
            token = client.send(:veis_token!)
            tokens_returned << token
            token
          end
        end

        # Wait for all threads
        results = threads.map(&:value)

        # Verify only one mint occurred
        expect(mint_count.value).to eq(1), "Expected exactly 1 mint, got #{mint_count.value}"

        # Verify we got mix of old and new tokens (race_condition_ttl behavior)
        expect(results.count(old_token)).to be_positive, 'Some threads should receive old token'
        expect(results.count('new-token-1')).to be_positive, 'At least one thread should receive new token'
        expect(results.length).to eq(10), 'All threads should return a token'
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

      it 'lazily initializes Redis client when needed for identity data' do
        # Mock the Redis client that will be lazily created
        lazy_redis_client = instance_double(TravelClaim::RedisClient)
        allow(TravelClaim::RedisClient).to receive(:build).and_return(lazy_redis_client)

        # Redis client should be nil before any operations
        expect(direct_client.instance_variable_get(:@redis_client)).to be_nil

        # Calling redis_client accessor should initialize it
        result = direct_client.send(:redis_client)

        # Redis client should now be initialized
        expect(result).to eq(lazy_redis_client)
        expect(direct_client.instance_variable_get(:@redis_client)).to be_present
      end

      it 'uses Rails.cache.fetch for VEIS token with lazy Redis initialization' do
        # Clear instance variable to force cache fetch
        direct_client.instance_variable_set(:@current_veis_token, nil)

        # Mock Rails.cache.fetch to return a token
        expect(Rails.cache).to receive(:fetch).with(
          'token',
          hash_including(
            namespace: 'check-in-btsss-cache-v1',
            expires_in: 54.minutes,
            race_condition_ttl: 5.minutes
          )
        ).and_return('cached-veis-token')

        result = direct_client.send(:veis_token!)

        expect(result).to eq('cached-veis-token')
        expect(direct_client.instance_variable_get(:@current_veis_token)).to eq('cached-veis-token')
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

  describe '#btsss_client_secret' do
    context 'when facility_type is "oh"' do
      it 'returns the OH-specific client secret' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      travel_pay_client_secret:,
                      travel_pay_client_secret_oh:) do
          client = described_class.new(check_in_uuid:, appointment_date_time:, facility_type: 'oh')
          expect(client.send(:btsss_client_secret)).to eq(travel_pay_client_secret_oh)
        end
      end

      it 'returns the OH-specific client secret for uppercase OH' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      travel_pay_client_secret:,
                      travel_pay_client_secret_oh:) do
          client = described_class.new(check_in_uuid:, appointment_date_time:, facility_type: 'OH')
          expect(client.send(:btsss_client_secret)).to eq(travel_pay_client_secret_oh)
        end
      end
    end

    context 'when facility_type is not "oh"' do
      it 'returns the standard client secret for vamc' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      travel_pay_client_secret:,
                      travel_pay_client_secret_oh:) do
          client = described_class.new(check_in_uuid:, appointment_date_time:, facility_type: 'vamc')
          expect(client.send(:btsss_client_secret)).to eq(travel_pay_client_secret)
        end
      end

      it 'returns the standard client secret when facility_type is nil' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      travel_pay_client_secret:,
                      travel_pay_client_secret_oh:) do
          client = described_class.new(check_in_uuid:, appointment_date_time:, facility_type: nil)
          expect(client.send(:btsss_client_secret)).to eq(travel_pay_client_secret)
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
                    claims_url_v2:, claims_base_path_v2:) do
        VCR.use_cassette('check_in/travel_claim/claims_submit_200') do
          result = client.send_claim_submission_request(claim_id: test_claim_id)

          expect(result).to respond_to(:status)
          expect(result.status).to eq(200)
        end
      end
    end
  end

  describe 'error details logging flipper behavior' do
    before do
      allow(client.redis_client).to receive(:token).and_return(test_veis_token)
      client.instance_variable_set(:@current_veis_token, test_veis_token)
      client.instance_variable_set(:@current_btsss_token, test_btsss_token)
      allow(Rails.logger).to receive(:error)
    end

    context 'when error details flipper is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:check_in_experience_travel_claim_log_api_error_details).and_return(false)
      end

      it 'logs error without api_error_message or error_detail fields' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          # Capture the logged hash
          logged_hash = nil
          allow(Rails.logger).to receive(:error) do |hash|
            logged_hash = hash
          end

          allow(client).to receive(:perform).and_raise(
            Common::Exceptions::BackendServiceException.new(
              'VA900',
              { detail: 'Sensitive error information' },
              400,
              'Bad Request'
            )
          )

          expect do
            client.send_claim_request(appointment_id: 'test-appt-id')
          end.to raise_error(Common::Exceptions::BackendServiceException)

          # Verify basic fields are present
          expect(logged_hash).to include(
            message: 'TravelPayClient: BTSSS API Error',
            endpoint: 'BTSSS',
            operation: 'create_claim',
            http_status: 400,
            error_class: 'Common::Exceptions::BackendServiceException',
            error_code: 'VA900'
          )

          # Verify sensitive fields are NOT present
          expect(logged_hash).not_to have_key(:api_error_message)
          expect(logged_hash).not_to have_key(:error_detail)
        end
      end
    end

    context 'when error details flipper is enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:check_in_experience_travel_claim_log_api_error_details).and_return(true)
      end

      it 'logs error with api_error_message and error_detail fields' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          allow(client).to receive(:perform).and_raise(
            Common::Exceptions::BackendServiceException.new(
              'VA900',
              { detail: 'Validation failed' },
              400,
              { message: 'Invalid request data' }.to_json
            )
          )

          expect do
            client.send_claim_request(appointment_id: 'test-appt-id')
          end.to raise_error(Common::Exceptions::BackendServiceException)

          expect(Rails.logger).to have_received(:error).with(
            hash_including(
              message: 'TravelPayClient: BTSSS API Error',
              endpoint: 'BTSSS',
              operation: 'create_claim',
              http_status: 400,
              error_class: 'Common::Exceptions::BackendServiceException',
              error_code: 'VA900',
              api_error_message: 'Invalid request data',
              error_detail: 'Validation failed'
            )
          )
        end
      end
    end
  end
end
