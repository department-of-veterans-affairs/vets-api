# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::ClaimSubmissionService do
  let(:check_in_session) { instance_double(CheckIn::V2::Session, uuid: 'test-uuid') }
  let(:appointment_date) { '2024-01-01T12:00:00Z' }
  let(:facility_type) { 'oh' }
  let(:redis_client) { instance_double(TravelClaim::RedisClient) }
  let(:travel_pay_client) { instance_double(TravelClaim::TravelPayClient) }

  before do
    allow(TravelClaim::RedisClient).to receive(:build).and_return(redis_client)
    allow(TravelClaim::TravelPayClient).to receive(:new).and_return(travel_pay_client)
    allow(Flipper).to receive(:enabled?).with('check_in_experience_mock_enabled').and_return(false)
    # Enable travel claim logging for tests
    allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_claim_logging).and_return(true)
    # Enable travel reimbursement (includes notifications) for tests
    allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_reimbursement).and_return(true)
    # Mock the notification job
    allow(CheckIn::TravelClaimNotificationJob).to receive(:perform_async)
  end

  describe '#submit_claim' do
    let(:icn) { 'test-icn' }
    let(:uuid) { 'test-uuid' }
    let(:service) { described_class.new(check_in: check_in_session, appointment_date:, facility_type:, uuid:) }

    before do
      allow(redis_client).to receive_messages(
        icn:,
        token: 'test_veis_token_123',
        save_token: nil
      )
      allow(redis_client).to receive(:station_number).with(uuid: 'test-uuid').and_return('500')
    end

    context 'when validation fails' do
      context 'when check_in is missing' do
        let(:service) { described_class.new(check_in: nil, appointment_date:, facility_type:, uuid:) }

        it 'raises BackendServiceException for missing check_in' do
          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      context 'when appointment_date is missing' do
        let(:service) { described_class.new(check_in: check_in_session, appointment_date: nil, facility_type:, uuid:) }

        it 'raises BackendServiceException for missing appointment_date' do
          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      context 'when facility_type is missing' do
        let(:service) { described_class.new(check_in: check_in_session, appointment_date:, facility_type: nil, uuid:) }

        it 'raises BackendServiceException for missing facility_type' do
          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      context 'when uuid is missing' do
        let(:service) { described_class.new(check_in: check_in_session, appointment_date:, facility_type:, uuid: nil) }

        it 'raises BackendServiceException for missing uuid' do
          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when all steps succeed' do
      it 'completes the full claim submission flow' do
        mock_successful_flow

        result = service.submit_claim

        expect(result).to be_a(Hash)
        expect(result['success']).to be true
        expect(result['claimId']).to eq('claim-456')
      end

      it 'sends success notification when feature flag is enabled' do
        mock_successful_flow_with_claim_response

        service.submit_claim

        expect(CheckIn::TravelClaimNotificationJob).to have_received(:perform_async).with(
          'test-uuid',
          '2024-01-01',
          CheckIn::Constants::OH_SUCCESS_TEMPLATE_ID,
          '6789'
        )
      end

      context 'with CIE facility type' do
        let(:facility_type) { 'cie' }

        it 'sends success notification with CIE template' do
          mock_successful_flow_with_claim_response

          service.submit_claim

          expect(CheckIn::TravelClaimNotificationJob).to have_received(:perform_async).with(
            'test-uuid',
            '2024-01-01',
            CheckIn::Constants::CIE_SUCCESS_TEMPLATE_ID,
            '6789'
          )
        end
      end

      context 'when notification feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_reimbursement).and_return(false)
        end

        it 'does not send notification' do
          mock_successful_flow

          service.submit_claim

          expect(CheckIn::TravelClaimNotificationJob).not_to have_received(:perform_async)
        end
      end
    end

    context 'when appointment request fails' do
      it 'raises backend service exception for appointment failure' do
        mock_appointment_failure(400)

        expect { service.submit_claim }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end

      it 'sends error notification when feature flag is enabled' do
        mock_appointment_failure(400)

        expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

        expect(CheckIn::TravelClaimNotificationJob).to have_received(:perform_async).with(
          'test-uuid',
          '2024-01-01',
          CheckIn::Constants::OH_ERROR_TEMPLATE_ID,
          'unknown'
        )
      end

      context 'with CIE facility type' do
        let(:facility_type) { 'cie' }

        it 'sends error notification with CIE template' do
          mock_appointment_failure(400)

          expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

          expect(CheckIn::TravelClaimNotificationJob).to have_received(:perform_async).with(
            'test-uuid',
            '2024-01-01',
            CheckIn::Constants::CIE_ERROR_TEMPLATE_ID,
            'unknown'
          )
        end
      end

      context 'when notification feature flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_reimbursement).and_return(false)
        end

        it 'does not send error notification' do
          mock_appointment_failure(400)

          expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

          expect(CheckIn::TravelClaimNotificationJob).not_to have_received(:perform_async)
        end
      end
    end

    context 'when claim creation fails' do
      it 'raises claim creation failed error' do
        mock_claim_creation_failure(400)

        expect { service.submit_claim }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end

    context 'when claim already exists for appointment' do
      before do
        allow(travel_pay_client).to receive(:send_appointment_request).and_return(
          double(body: { 'data' => [{ 'id' => 'appointment-123' }] })
        )
        allow(travel_pay_client).to receive(:send_claim_request).and_raise(
          Common::Exceptions::BackendServiceException.new(
            'VA900',
            { detail: 'Validation failed: A claim has already been created for this appointment.' },
            400
          )
        )
      end

      it 'sends duplicate claim notification for OH facility' do
        expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

        expect(CheckIn::TravelClaimNotificationJob).to have_received(:perform_async).with(
          'test-uuid',
          '2024-01-01',
          CheckIn::Constants::OH_DUPLICATE_TEMPLATE_ID,
          'unknown'
        )
      end

      context 'with CIE facility type' do
        let(:facility_type) { 'vamc' }

        it 'sends duplicate claim notification for CIE facility' do
          expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

          expect(CheckIn::TravelClaimNotificationJob).to have_received(:perform_async).with(
            'test-uuid',
            '2024-01-01',
            CheckIn::Constants::CIE_DUPLICATE_TEMPLATE_ID,
            'unknown'
          )
        end
      end
    end

    context 'when mileage expense creation fails' do
      it 'raises expense addition failed error' do
        mock_expense_failure(500)

        expect { service.submit_claim }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end

    context 'when claim submission fails' do
      it 'raises claim submission failed error' do
        mock_submission_failure(500)

        expect { service.submit_claim }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end

    context 'when authentication fails' do
      context 'when VEIS token request fails' do
        it 'raises authentication error' do
          allow(travel_pay_client).to receive(:send_appointment_request)
            .and_raise(Common::Exceptions::BackendServiceException.new(
                         'VA900',
                         { detail: 'VEIS response missing access_token' },
                         502
                       ))

          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      context 'when system access token request fails' do
        it 'raises authentication error' do
          allow(travel_pay_client).to receive(:send_appointment_request)
            .and_raise(Common::Exceptions::BackendServiceException.new(
                         'VA900',
                         { detail: 'BTSSS response missing accessToken in data' },
                         502
                       ))

          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when appointment response is malformed' do
      it 'raises backend service exception for malformed appointment response' do
        mock_malformed_response(:appointment, { 'data' => [] }) # Empty array - missing appointment with 'id'

        expect { service.submit_claim }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end

    context 'when claim response is malformed' do
      it 'raises backend service exception for malformed claim response' do
        mock_malformed_response(:claim, { 'data' => {} }) # Missing 'claimId'

        expect { service.submit_claim }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end

    context 'when expense response is malformed' do
      it 'raises backend service exception for malformed expense response' do
        mock_malformed_response(:expense)

        expect { service.submit_claim }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end

    context 'when claim submission response is malformed' do
      it 'raises backend service exception for malformed submission response' do
        mock_malformed_response(:submission)

        expect { service.submit_claim }.to raise_error(
          Common::Exceptions::BackendServiceException
        )
      end
    end

    context 'when business rules are violated' do
      context 'when appointment date is in the future' do
        let(:appointment_date) { '2025-12-31T12:00:00Z' }

        it 'raises business rule violation error' do
          mock_appointment_failure(400) # Business rule violation

          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      context 'when facility type is not supported' do
        let(:facility_type) { 'unsupported_type' }

        it 'raises facility not supported error' do
          mock_appointment_failure(400) # Facility not supported

          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when network infrastructure fails' do
      context 'when request times out' do
        it 'raises timeout error' do
          mock_appointment_failure(504) # Gateway timeout

          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      context 'when service is unavailable' do
        it 'raises service unavailable error' do
          mock_appointment_failure(503) # Service unavailable

          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#log_message' do
    let(:uuid) { 'test-uuid' }
    let(:service) { described_class.new(check_in: check_in_session, appointment_date:, facility_type:, uuid:) }

    context 'when check_in_experience_travel_claim_logging feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_claim_logging).and_return(true)
        allow(Rails.logger).to receive(:info)
      end

      it 'logs the message with proper formatting' do
        service.send(:log_message, :info, 'Test message', { extra: 'data' })

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            message: 'CIE Travel Claim Submission: Test message',
            facility_type: 'oh',
            check_in_uuid: 'test-uuid',
            extra: 'data'
          )
        )
      end
    end

    context 'when check_in_experience_travel_claim_logging feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_claim_logging).and_return(false)
        allow(Rails.logger).to receive(:info)
      end

      it 'does not log anything' do
        service.send(:log_message, :info, 'Test message', { extra: 'data' })

        expect(Rails.logger).not_to have_received(:info)
      end
    end
  end

  describe 'notification helper methods' do
    let(:uuid) { 'test-uuid' }
    let(:service) { described_class.new(check_in: check_in_session, appointment_date:, facility_type:, uuid:) }

    describe '#extract_claim_number_last_four' do
      context 'with valid response body' do
        let(:response) do
          double(body: {
                   'data' => {
                     'claimId' => '97d2e536-017e-f011-b4cc-001dd8066789'
                   }
                 })
        end

        it 'extracts last four digits of claim ID' do
          result = service.send(:extract_claim_number_last_four, response)
          expect(result).to eq('6789')
        end
      end

      context 'with JSON string response body' do
        let(:response) do
          double(body: '{"data":{"claimId":"97d2e536-017e-f011-b4cc-001dd8066789"}}')
        end

        it 'parses JSON and extracts last four digits' do
          result = service.send(:extract_claim_number_last_four, response)
          expect(result).to eq('6789')
        end
      end

      context 'with missing claim ID' do
        let(:response) { double(body: { 'data' => {} }) }

        it 'returns unknown for missing claim ID' do
          result = service.send(:extract_claim_number_last_four, response)
          expect(result).to eq('unknown')
        end
      end

      context 'with malformed response' do
        let(:response) { double(body: 'invalid json') }

        it 'returns unknown for parsing errors' do
          allow(Rails.logger).to receive(:error)
          result = service.send(:extract_claim_number_last_four, response)
          expect(result).to eq('unknown')
        end
      end
    end

    describe '#success_template_id' do
      context 'with OH facility type' do
        let(:facility_type) { 'oh' }

        it 'returns OH success template' do
          template_id = service.send(:success_template_id)
          expect(template_id).to eq(CheckIn::Constants::OH_SUCCESS_TEMPLATE_ID)
        end
      end

      context 'with CIE facility type' do
        let(:facility_type) { 'cie' }

        it 'returns CIE success template' do
          template_id = service.send(:success_template_id)
          expect(template_id).to eq(CheckIn::Constants::CIE_SUCCESS_TEMPLATE_ID)
        end
      end

      context 'with unknown facility type' do
        let(:facility_type) { 'unknown' }

        it 'defaults to CIE success template' do
          template_id = service.send(:success_template_id)
          expect(template_id).to eq(CheckIn::Constants::CIE_SUCCESS_TEMPLATE_ID)
        end
      end
    end

    describe '#error_template_id' do
      context 'with OH facility type' do
        let(:facility_type) { 'oh' }

        it 'returns OH error template' do
          template_id = service.send(:error_template_id)
          expect(template_id).to eq(CheckIn::Constants::OH_ERROR_TEMPLATE_ID)
        end
      end

      context 'with CIE facility type' do
        let(:facility_type) { 'cie' }

        it 'returns CIE error template' do
          template_id = service.send(:error_template_id)
          expect(template_id).to eq(CheckIn::Constants::CIE_ERROR_TEMPLATE_ID)
        end
      end
    end

    describe '#format_appointment_date' do
      context 'with valid ISO date' do
        let(:appointment_date) { '2024-01-15T14:30:00Z' }

        it 'formats date correctly' do
          formatted_date = service.send(:format_appointment_date)
          expect(formatted_date).to eq('2024-01-15')
        end
      end

      context 'with invalid date' do
        let(:appointment_date) { 'invalid-date' }

        it 'returns original date on parsing error' do
          allow(Rails.logger).to receive(:error)
          formatted_date = service.send(:format_appointment_date)
          expect(formatted_date).to eq('invalid-date')
        end
      end
    end
  end

  # Helper methods for common mock setups
  def mock_successful_flow
    allow(travel_pay_client).to receive_messages(
      send_appointment_request: double(body: { 'data' => [{ 'id' => 'appointment-123' }] }, status: 200),
      send_claim_request: double(body: { 'data' => { 'claimId' => 'claim-456' } }, status: 200),
      send_mileage_expense_request: double(status: 200),
      send_claim_submission_request: double(
        body: { 'data' => { 'claimId' => 'claim-456-6789' } },
        status: 200
      )
    )
  end

  def mock_successful_flow_with_claim_response
    mock_successful_appointment
    mock_successful_claim_creation
    mock_successful_expense
    mock_successful_claim_submission_with_response
  end

  def mock_successful_claim_submission_with_response
    response_body = {
      'data' => { 'claimId' => '97d2e536-017e-f011-b4cc-001dd8066789' },
      'success' => true,
      'statusCode' => 200
    }
    allow(travel_pay_client).to receive(:send_claim_submission_request)
      .and_return(double(body: response_body, status: 200))
  end

  def mock_appointment_failure(status = 400)
    allow(travel_pay_client).to receive(:send_appointment_request)
      .and_return(double(body: { 'error' => 'Appointment not found' }, status:))
  end

  def mock_claim_creation_failure(status = 400)
    mock_successful_appointment
    allow(travel_pay_client).to receive(:send_claim_request)
      .and_return(double(body: { 'error' => 'Claim creation failed' }, status:))
  end

  def mock_expense_failure(status = 400)
    mock_successful_appointment
    mock_successful_claim_creation
    allow(travel_pay_client).to receive(:send_mileage_expense_request)
      .and_return(double(status:))
  end

  def mock_submission_failure(status = 400)
    mock_successful_appointment
    mock_successful_claim_creation
    mock_successful_expense
    allow(travel_pay_client).to receive(:send_claim_submission_request)
      .and_return(double(status:))
  end

  def mock_successful_appointment
    allow(travel_pay_client).to receive(:send_appointment_request)
      .and_return(double(body: { 'data' => [{ 'id' => 'appointment-123' }] }, status: 200))
  end

  def mock_successful_claim_creation
    allow(travel_pay_client).to receive(:send_claim_request)
      .and_return(double(body: { 'data' => { 'claimId' => 'claim-456' } }, status: 200))
  end

  def mock_successful_expense
    allow(travel_pay_client).to receive(:send_mileage_expense_request)
      .and_return(double(status: 200))
  end

  def mock_malformed_response(endpoint, response_body = {})
    case endpoint
    when :appointment
      allow(travel_pay_client).to receive(:send_appointment_request)
        .and_return(double(body: response_body, status: 200))
    when :claim
      mock_successful_appointment
      allow(travel_pay_client).to receive(:send_claim_request)
        .and_return(double(body: response_body, status: 200))
    when :expense
      mock_successful_appointment
      mock_successful_claim_creation
      allow(travel_pay_client).to receive(:send_mileage_expense_request)
        .and_return(double(status: 400)) # Non-200 status to trigger failure
    when :submission
      mock_successful_appointment
      mock_successful_claim_creation
      mock_successful_expense
      allow(travel_pay_client).to receive(:send_claim_submission_request)
        .and_return(double(status: 400)) # Non-200 status to trigger failure
    end
  end
end
