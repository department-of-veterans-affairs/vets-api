# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::ClaimSubmissionService do
  let(:appointment_date) { '2024-01-01T12:00:00Z' }
  let(:facility_type) { 'oh' }
  let(:check_in_uuid) { 'test-uuid' }
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
    let(:service) { described_class.new(appointment_date:, facility_type:, check_in_uuid:) }

    before do
      allow(redis_client).to receive_messages(
        icn:,
        token: 'test_veis_token_123',
        save_token: nil
      )
      allow(redis_client).to receive(:station_number).with(uuid: 'test-uuid').and_return('500')
    end

    context 'when validation fails' do
      context 'when appointment_date is missing' do
        let(:service) { described_class.new(appointment_date: nil, facility_type:, check_in_uuid:) }

        it 'raises BackendServiceException for missing appointment_date' do
          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      context 'when facility_type is missing' do
        let(:service) { described_class.new(appointment_date:, facility_type: nil, check_in_uuid:) }

        it 'raises BackendServiceException for missing facility_type' do
          expect { service.submit_claim }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end

      context 'when check_in_uuid is missing' do
        let(:service) { described_class.new(appointment_date:, facility_type:, check_in_uuid: nil) }

        it 'raises BackendServiceException for missing check_in_uuid' do
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

  describe 'service-level logging' do
    let(:service) { described_class.new(appointment_date:, facility_type:, check_in_uuid:) }

    context 'when check_in_experience_travel_claim_logging feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_claim_logging).and_return(true)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
      end

      it 'logs submission start' do
        service.send(:log_submission_start)

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            message: 'Travel Claim Submission: START',
            facility_type: 'oh',
            check_in_uuid: 'test-uuid'
          )
        )
      end

      it 'logs submission success with claim ID' do
        result = { 'claimId' => 'test-claim-123', 'success' => true }
        service.send(:log_submission_success, result)

        expect(Rails.logger).to have_received(:info).with(
          hash_including(
            message: 'Travel Claim Submission: SUCCESS',
            facility_type: 'oh',
            check_in_uuid: 'test-uuid',
            claim_id: 'test-claim-123'
          )
        )
      end

      it 'logs submission failure with step and error class' do
        error = StandardError.new('test error')
        service.instance_variable_set(:@current_step, 'create_claim')
        service.send(:log_submission_failure, error:)

        expect(Rails.logger).to have_received(:error).with(
          hash_including(
            message: 'Travel Claim Submission: FAILURE',
            facility_type: 'oh',
            check_in_uuid: 'test-uuid',
            failed_step: 'create_claim',
            error_class: 'StandardError'
          )
        )
      end
    end

    context 'when check_in_experience_travel_claim_logging feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:check_in_experience_travel_claim_logging).and_return(false)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
      end

      it 'does not log anything' do
        service.send(:log_submission_start)
        result = { 'claimId' => 'test-claim-123' }
        service.send(:log_submission_success, result)
        error = StandardError.new('test error')
        service.send(:log_submission_failure, error:)

        expect(Rails.logger).not_to have_received(:info)
        expect(Rails.logger).not_to have_received(:error)
      end
    end
  end

  describe 'StatsD metrics' do
    let(:service) { described_class.new(appointment_date:, facility_type:, check_in_uuid:) }

    before do
      allow(StatsD).to receive(:increment)
    end

    describe 'success metrics' do
      context 'when claim submission succeeds for OH facility' do
        it 'increments OH success metric' do
          mock_successful_flow

          service.submit_claim

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_BTSSS_SUCCESS)
        end
      end

      context 'when claim submission succeeds for CIE facility' do
        let(:facility_type) { 'cie' }

        it 'increments CIE success metric' do
          mock_successful_flow

          service.submit_claim

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_BTSSS_SUCCESS)
        end
      end
    end

    describe 'error metrics' do
      context 'when appointment request fails' do
        it 'increments appointment error metric and general failure metric for OH facility' do
          mock_appointment_failure(400)

          expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_APPOINTMENT_ERROR)
          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_BTSSS_CLAIM_FAILURE)
        end

        context 'with CIE facility type' do
          let(:facility_type) { 'cie' }

          it 'increments appointment error metric and general failure metric for CIE facility' do
            mock_appointment_failure(400)

            expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

            expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_APPOINTMENT_ERROR)
            expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_BTSSS_CLAIM_FAILURE)
          end
        end
      end

      context 'when claim creation fails' do
        it 'increments claim creation error metric and general failure metric for OH facility' do
          mock_claim_creation_failure(400)

          expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_CLAIM_CREATE_ERROR)
          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_BTSSS_CLAIM_FAILURE)
        end

        context 'with CIE facility type' do
          let(:facility_type) { 'cie' }

          it 'increments claim creation error metric and general failure metric for CIE facility' do
            mock_claim_creation_failure(400)

            expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

            expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_CLAIM_CREATE_ERROR)
            expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_BTSSS_CLAIM_FAILURE)
          end
        end
      end

      context 'when expense addition fails' do
        it 'increments expense addition error metric and general failure metric for OH facility' do
          mock_expense_failure(500)

          expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_EXPENSE_ADD_ERROR)
          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_BTSSS_CLAIM_FAILURE)
        end

        context 'with CIE facility type' do
          let(:facility_type) { 'cie' }

          it 'increments expense addition error metric and general failure metric for CIE facility' do
            mock_expense_failure(500)

            expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

            expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_EXPENSE_ADD_ERROR)
            expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_BTSSS_CLAIM_FAILURE)
          end
        end
      end

      context 'when claim submission fails' do
        it 'increments claim submission error metric and general failure metric for OH facility' do
          mock_submission_failure(500)

          expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_CLAIM_SUBMIT_ERROR)
          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_BTSSS_CLAIM_FAILURE)
        end

        context 'with CIE facility type' do
          let(:facility_type) { 'cie' }

          it 'increments claim submission error metric and general failure metric for CIE facility' do
            mock_submission_failure(500)

            expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

            expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_CLAIM_SUBMIT_ERROR)
            expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_BTSSS_CLAIM_FAILURE)
          end
        end
      end
    end

    describe 'duplicate claim metrics' do
      context 'when claim already exists for OH facility' do
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

        it 'increments OH duplicate claim metric and general failure metric' do
          expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_BTSSS_DUPLICATE)
          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_BTSSS_CLAIM_FAILURE)
        end
      end

      context 'when claim already exists for CIE facility' do
        let(:facility_type) { 'cie' }

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

        it 'increments CIE duplicate claim metric and general failure metric' do
          expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_BTSSS_DUPLICATE)
          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::CIE_STATSD_BTSSS_CLAIM_FAILURE)
        end
      end

      context 'when duplicate claim error has different message format' do
        before do
          allow(travel_pay_client).to receive(:send_appointment_request).and_return(
            double(body: { 'data' => [{ 'id' => 'appointment-123' }] })
          )
          allow(travel_pay_client).to receive(:send_claim_request).and_raise(
            Common::Exceptions::BackendServiceException.new(
              'VA900',
              { detail: 'A claim already exists for this appointment' },
              400
            )
          )
        end

        it 'increments duplicate claim metric and general failure metric for OH facility' do
          expect { service.submit_claim }.to raise_error(Common::Exceptions::BackendServiceException)

          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_BTSSS_DUPLICATE)
          expect(StatsD).to have_received(:increment).with(CheckIn::Constants::OH_STATSD_BTSSS_CLAIM_FAILURE)
        end
      end
    end

    describe 'duplicate claim detection' do
      let(:service) { described_class.new(appointment_date:, facility_type:, check_in_uuid:) }

      describe '#duplicate_claim_error?' do
        it 'returns true for "already been created" error' do
          error = Common::Exceptions::BackendServiceException.new(
            'VA900',
            { detail: 'A claim has already been created for this appointment' },
            400
          )

          expect(service.send(:duplicate_claim_error?, error)).to be true
        end

        it 'returns true for "already exists" error' do
          error = Common::Exceptions::BackendServiceException.new(
            'VA900',
            { detail: 'A claim already exists for this appointment' },
            400
          )

          expect(service.send(:duplicate_claim_error?, error)).to be true
        end

        it 'returns true for "duplicate" error' do
          error = Common::Exceptions::BackendServiceException.new(
            'VA900',
            { detail: 'duplicate claim detected' },
            400
          )

          expect(service.send(:duplicate_claim_error?, error)).to be true
        end

        it 'returns true for error with standardized duplicate claim code' do
          error = Common::Exceptions::BackendServiceException.new(
            'VA900',
            { detail: 'CLM_002_CLAIM_EXISTS: A claim has already been created for this appointment' },
            400
          )

          expect(service.send(:duplicate_claim_error?, error)).to be true
        end

        it 'returns false for other errors' do
          error = Common::Exceptions::BackendServiceException.new(
            'VA900',
            { detail: 'Appointment not found' },
            400
          )

          expect(service.send(:duplicate_claim_error?, error)).to be false
        end

        it 'returns false for errors without detail' do
          error = Common::Exceptions::BackendServiceException.new(
            'VA900',
            {},
            400
          )

          expect(service.send(:duplicate_claim_error?, error)).to be_falsy
        end
      end
    end
  end

  describe 'notification helper methods' do
    let(:service) { described_class.new(appointment_date:, facility_type:, check_in_uuid:) }

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
