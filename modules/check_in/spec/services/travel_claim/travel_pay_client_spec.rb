# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::TravelPayClient do
  let(:check_in_uuid) { 'test-uuid-123' }
  let(:appointment_date_time) { '2024-01-01T12:00:00Z' }
  let(:test_station_number) { '500' }
  let(:test_correlation_id) { 'test-correlation-id' }

  # Test data constants
  let(:test_veis_token) { 'fake_veis_token_123' }
  let(:test_btsss_token) { 'fake_btsss_token_456' }
  let(:test_appointment_id) { 'appt-123' }
  let(:test_claim_id) { 'claim-456' }
  let(:test_date_incurred) { '2024-01-15' }

  # Settings constants
  let(:claims_url_v2) { 'https://dev.integration.d365.va.gov' }
  let(:claims_base_path_v2) { 'eis/api/btsss/travelclaim' }
  let(:subscription_key) { 'sub-key' }

  before do
    allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_claim_logging).and_return(false)
    allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_claim_log_api_error_details).and_return(false)
  end

  describe 'initialization' do
    context 'with valid parameters' do
      it 'accepts appointment_date_time and station_number parameters' do
        client = described_class.new(
          appointment_date_time:,
          station_number: test_station_number
        )
        expect(client).to be_a(described_class)
      end

      it 'generates a correlation_id if not provided' do
        client = described_class.new(
          appointment_date_time:,
          station_number: test_station_number
        )
        expect(client.instance_variable_get(:@correlation_id)).to be_present
      end

      it 'uses provided correlation_id' do
        client = described_class.new(
          appointment_date_time:,
          station_number: test_station_number,
          correlation_id: test_correlation_id
        )
        expect(client.instance_variable_get(:@correlation_id)).to eq(test_correlation_id)
      end

      it 'accepts optional check_in_uuid for logging context' do
        client = described_class.new(
          appointment_date_time:,
          station_number: test_station_number,
          check_in_uuid:
        )
        expect(client.instance_variable_get(:@check_in_uuid)).to eq(check_in_uuid)
      end

      it 'accepts optional facility_type for logging context' do
        client = described_class.new(
          appointment_date_time:,
          station_number: test_station_number,
          facility_type: 'oh'
        )
        expect(client.instance_variable_get(:@facility_type)).to eq('oh')
      end
    end

    context 'with missing required parameters' do
      it 'raises ArgumentError when appointment_date_time is blank' do
        expect do
          described_class.new(
            appointment_date_time: nil,
            station_number: test_station_number
          )
        end.to raise_error(ArgumentError, /appointment_date_time is required/)
      end

      it 'raises ArgumentError when station_number is blank' do
        expect do
          described_class.new(
            appointment_date_time:,
            station_number: nil
          )
        end.to raise_error(ArgumentError, /station_number is required/)
      end
    end
  end

  describe 'API operations' do
    let(:client) do
      described_class.new(
        appointment_date_time:,
        station_number: test_station_number,
        check_in_uuid:,
        correlation_id: test_correlation_id
      )
    end

    describe '#send_appointment_request' do
      it 'makes appointment request with tokens' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          VCR.use_cassette('check_in/travel_claim/appointments_find_or_add_200') do
            result = client.send_appointment_request(
              veis_token: test_veis_token,
              btsss_token: test_btsss_token
            )

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
              expect do
                client.send_appointment_request(
                  veis_token: test_veis_token,
                  btsss_token: test_btsss_token
                )
              end.to raise_error(Common::Exceptions::BackendServiceException)
            end
          end
        end
      end
    end

    describe '#send_claim_request' do
      let(:appointment_id) { test_appointment_id }

      it 'makes claim request with tokens' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          VCR.use_cassette('check_in/travel_claim/claims_create_200') do
            result = client.send_claim_request(
              veis_token: test_veis_token,
              btsss_token: test_btsss_token,
              appointment_id:
            )

            expect(result).to respond_to(:status)
            expect(result).to respond_to(:body)
            expect(result.status).to eq(200)

            response_body = result.body.is_a?(String) ? JSON.parse(result.body) : result.body
            expect(response_body['success']).to be true
          end
        end
      end

      context 'when claim creation fails' do
        it 'raises BackendServiceException for duplicate appointment' do
          with_settings(Settings.check_in.travel_reimbursement_api_v2,
                        claims_url_v2:, claims_base_path_v2:) do
            VCR.use_cassette('check_in/travel_claim/claims_create_400_duplicate') do
              expect do
                client.send_claim_request(
                  veis_token: test_veis_token,
                  btsss_token: test_btsss_token,
                  appointment_id: 'duplicate-appt-id'
                )
              end.to raise_error(Common::Exceptions::BackendServiceException)
            end
          end
        end
      end
    end

    describe '#send_get_claim_request' do
      let(:claim_id) { test_claim_id }

      it 'makes get claim request with tokens' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          VCR.use_cassette('check_in/travel_claim/claims_get_200') do
            result = client.send_get_claim_request(
              veis_token: test_veis_token,
              btsss_token: test_btsss_token,
              claim_id:
            )

            expect(result).to respond_to(:status)
            expect(result).to respond_to(:body)
            expect(result.status).to eq(200)
          end
        end
      end

      context 'when claim is not found' do
        it 'raises BackendServiceException for 404 response' do
          allow(client).to receive(:perform).and_raise(
            Common::Exceptions::BackendServiceException.new('VA900', {}, 404, 'Not Found')
          )

          expect do
            client.send_get_claim_request(
              veis_token: test_veis_token,
              btsss_token: test_btsss_token,
              claim_id: 'nonexistent-claim'
            )
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end

      context 'when server error occurs' do
        it 'raises BackendServiceException for 500 response' do
          allow(client).to receive(:perform).and_raise(
            Common::Exceptions::BackendServiceException.new('VA900', {}, 500, 'Server Error')
          )

          expect do
            client.send_get_claim_request(
              veis_token: test_veis_token,
              btsss_token: test_btsss_token,
              claim_id: 'error-claim'
            )
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end

    describe '#send_mileage_expense_request' do
      it 'makes mileage expense request with tokens' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          VCR.use_cassette('check_in/travel_claim/expenses_mileage_200') do
            result = client.send_mileage_expense_request(
              veis_token: test_veis_token,
              btsss_token: test_btsss_token,
              claim_id: test_claim_id,
              date_incurred: test_date_incurred
            )

            expect(result).to respond_to(:status)
            expect(result.status).to eq(200)
          end
        end
      end
    end

    describe '#send_claim_submission_request' do
      it 'makes claim submission request with tokens' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          VCR.use_cassette('check_in/travel_claim/claims_submit_200') do
            result = client.send_claim_submission_request(
              veis_token: test_veis_token,
              btsss_token: test_btsss_token,
              claim_id: test_claim_id
            )

            expect(result).to respond_to(:status)
            expect(result.status).to eq(200)
          end
        end
      end
    end
  end

  describe '#build_headers' do
    let(:client) do
      described_class.new(
        appointment_date_time:,
        station_number: test_station_number,
        correlation_id: test_correlation_id
      )
    end

    it 'builds headers with tokens and correlation ID' do
      headers = client.send(:build_headers, veis_token: test_veis_token, btsss_token: test_btsss_token)

      expect(headers['Content-Type']).to eq('application/json')
      expect(headers['Authorization']).to eq("Bearer #{test_veis_token}")
      expect(headers['BTSSS-Access-Token']).to eq(test_btsss_token)
      expect(headers['X-Correlation-ID']).to eq(test_correlation_id)
    end

    context 'in non-production environment' do
      it 'includes single subscription key' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2, subscription_key:) do
          headers = client.send(:build_headers, veis_token: test_veis_token, btsss_token: test_btsss_token)
          expect(headers['Ocp-Apim-Subscription-Key']).to eq(subscription_key)
        end
      end
    end

    context 'in production environment' do
      before do
        allow(Settings).to receive(:vsp_environment).and_return('production')
      end

      it 'includes E and S subscription keys' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      e_subscription_key: 'e-key', s_subscription_key: 's-key') do
          headers = client.send(:build_headers, veis_token: test_veis_token, btsss_token: test_btsss_token)
          expect(headers['Ocp-Apim-Subscription-Key-E']).to eq('e-key')
          expect(headers['Ocp-Apim-Subscription-Key-S']).to eq('s-key')
        end
      end
    end
  end

  describe '#config' do
    let(:client) do
      described_class.new(
        appointment_date_time:,
        station_number: test_station_number
      )
    end

    it 'returns the TravelClaim::Configuration instance' do
      expect(client.config).to eq(TravelClaim::Configuration.instance)
    end
  end

  describe '#patch method override' do
    let(:client) do
      described_class.new(
        appointment_date_time:,
        station_number: test_station_number,
        check_in_uuid:
      )
    end

    it 'calls request method directly for PATCH requests' do
      expect(client).to receive(:request).with(:patch, anything, anything, anything, anything)

      with_settings(Settings.check_in.travel_reimbursement_api_v2,
                    claims_url_v2:, claims_base_path_v2:) do
        VCR.use_cassette('check_in/travel_claim/claims_submit_200') do
          client.send_claim_submission_request(
            veis_token: test_veis_token,
            btsss_token: test_btsss_token,
            claim_id: test_claim_id
          )
        end
      end
    end
  end

  describe '#extract_and_redact_message' do
    let(:client) do
      described_class.new(
        appointment_date_time:,
        station_number: test_station_number
      )
    end

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

  describe 'error logging' do
    let(:client) do
      described_class.new(
        appointment_date_time:,
        station_number: test_station_number,
        check_in_uuid:
      )
    end

    before do
      allow(Rails.logger).to receive(:error)
    end

    context 'when API request fails' do
      it 'logs error details' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:, claims_base_path_v2:) do
          allow(client).to receive(:perform).and_raise(
            Common::Exceptions::BackendServiceException.new('TEST', {}, 500, 'Internal Server Error')
          )

          expect do
            client.send_appointment_request(
              veis_token: test_veis_token,
              btsss_token: test_btsss_token
            )
          end.to raise_error(Common::Exceptions::BackendServiceException)

          expect(Rails.logger).to have_received(:error).with(
            hash_including(
              message: 'TravelPayClient: BTSSS API Error',
              operation: 'find_or_add_appointment',
              api_path: 'api/v3/appointments/find-or-add',
              http_status: 500,
              error_class: 'Common::Exceptions::BackendServiceException'
            )
          )
        end
      end
    end

    context 'when error details flipper is enabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:check_in_experience_travel_claim_log_api_error_details).and_return(true)
      end

      it 'logs api_error_message and error_detail fields' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:) do
          error_body = { 'message' => 'Detailed error message' }.to_json
          exception = Common::Exceptions::BackendServiceException.new(
            'VA900',
            { detail: 'Error detail from exception' },
            400,
            error_body
          )
          allow(client).to receive(:perform).and_raise(exception)

          expect do
            client.send_appointment_request(
              veis_token: test_veis_token,
              btsss_token: test_btsss_token
            )
          end.to raise_error(Common::Exceptions::BackendServiceException)

          expect(Rails.logger).to have_received(:error).with(
            hash_including(
              api_error_message: 'Detailed error message',
              error_detail: 'Error detail from exception'
            )
          )
        end
      end
    end

    context 'when error details flipper is disabled' do
      before do
        allow(Flipper).to receive(:enabled?)
          .with(:check_in_experience_travel_claim_log_api_error_details).and_return(false)
      end

      it 'logs error without api_error_message or error_detail fields' do
        with_settings(Settings.check_in.travel_reimbursement_api_v2,
                      claims_url_v2:) do
          error_body = { 'message' => 'Detailed error message' }.to_json
          exception = Common::Exceptions::BackendServiceException.new(
            'VA900',
            { detail: 'Error detail from exception' },
            400,
            error_body
          )
          allow(client).to receive(:perform).and_raise(exception)

          expect do
            client.send_appointment_request(
              veis_token: test_veis_token,
              btsss_token: test_btsss_token
            )
          end.to raise_error(Common::Exceptions::BackendServiceException)

          expect(Rails.logger).to have_received(:error).with(
            hash_excluding(:api_error_message, :error_detail)
          )
        end
      end
    end
  end
end
