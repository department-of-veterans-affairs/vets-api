# frozen_string_literal: true

require 'rails_helper'

describe Eps::AppointmentService do
  subject(:service) { described_class.new(user) }

  let(:user) do
    double('User', account_uuid: '1234', icn:, uuid: '1234', email: 'test@example.com',
                   va_profile_email: 'va.profile@example.com', va_treatment_facility_ids: ['123'])
  end
  let(:config) { instance_double(Eps::Configuration) }
  let(:headers) { { 'Authorization' => 'Bearer token123', 'X-Correlation-ID' => 'test-correlation-id' } }
  let(:response_headers) { { 'Content-Type' => 'application/json', 'x-wellhive-trace-id' => 'test-trace-id-123' } }

  let(:appointment_id) { 'appointment-123' }
  let(:icn) { '123ICN' }

  before do
    allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false, api_url: 'https://api.wellhive.com')
    allow_any_instance_of(Eps::BaseService).to receive_messages(config:)
    allow_any_instance_of(Eps::BaseService).to receive(:request_headers_with_correlation_id).and_return(headers)
    # Set up RequestStore for controller name logging
    RequestStore.store['controller_name'] = 'VAOS::V2::AppointmentsController'
  end

  describe '#get_appointment' do
    let(:success_response) do
      double('Response', status: 200, body: { 'id' => appointment_id,
                                              'state' => 'submitted',
                                              'patientId' => icn },
                         response_headers:)
    end

    context 'when the request is successful' do
      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(success_response)
      end

      it 'returns appointment details' do
        response = service.get_appointment(appointment_id:)
        expect(response.id).to eq(appointment_id)
        expect(response.state).to eq('submitted')
        expect(response.patientId).to eq(icn)
      end

      context 'when retrieve_latest_details is true' do
        before do
          path = "/#{config.base_path}/appointments/#{appointment_id}?retrieveLatestDetails=true"
          expect_any_instance_of(VAOS::SessionService).to receive(:perform)
            .with(:get, path, {}, headers)
            .and_return(success_response)
        end

        it 'includes the retrieveLatestDetails query parameter' do
          response = service.get_appointment(appointment_id:, retrieve_latest_details: true)
          expect(response.id).to eq(appointment_id)
        end
      end
    end

    context 'when the endpoint fails to return appointments' do
      let(:failed_appt_response) do
        double('Response', status: 500, body: 'Unknown service exception',
                           response_headers:)
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, failed_appt_response.status,
                                                        failed_appt_response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'throws exception' do
        expect { service.get_appointment(appointment_id:) }.to raise_error(Common::Exceptions::BackendServiceException,
                                                                           /VA900/)
      end
    end

    context 'when response contains error field' do
      let(:error_response) do
        double('Response', status: 200, body: { 'id' => appointment_id,
                                                'state' => 'submitted',
                                                'patientId' => icn,
                                                'error' => 'conflict' },
                           response_headers:)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(error_response)
        allow(Rails.logger).to receive(:warn)
        # Mock the trace ID in RequestStore since middleware doesn't run in unit tests
        RequestStore.store['eps_trace_id'] = 'test-trace-id-123'
      end

      it 'raises Eps::ServiceException' do
        expect { service.get_appointment(appointment_id:) }
          .to raise_error(Eps::ServiceException)
      end

      it 'logs the error without PII' do
        expected_controller_name = 'VAOS::V2::AppointmentsController'
        expected_station_number = user.va_treatment_facility_ids&.first

        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: EPS appointment error',
          {
            error_type: 'conflict',
            method: 'get_appointment',
            status: 200,
            controller: expected_controller_name,
            station_number: expected_station_number,
            eps_trace_id: 'test-trace-id-123'
          }
        )

        expect { service.get_appointment(appointment_id:) }
          .to raise_error(Eps::ServiceException)
      end
    end

    context 'when an unexpected error occurs' do
      let(:error_message) do
        'Connection failed for ICN 1234567890V123456 with referralNumber=REF-12345 and referral VA0000005681'
      end
      let(:unexpected_error) { StandardError.new(error_message) }

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(unexpected_error)
        allow(Rails.logger).to receive(:error)
        RequestStore.store['eps_trace_id'] = 'test-trace-id-123'
      end

      it 'logs the error with sanitized PII' do
        expected_controller_name = 'VAOS::V2::AppointmentsController'
        expected_station_number = user.va_treatment_facility_ids&.first

        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: EPS unexpected error',
          hash_including(
            service: 'EPS',
            method: 'get_appointment',
            error_class: 'StandardError',
            controller: expected_controller_name,
            station_number: expected_station_number,
            eps_trace_id: 'test-trace-id-123'
          )
        )

        expect { service.get_appointment(appointment_id:) }
          .to raise_error(StandardError)
      end

      it 'sanitizes ICN from error message' do
        expect(Rails.logger).to receive(:error) do |_msg, context|
          expect(context[:error_message]).not_to include('1234567890V123456')
          expect(context[:error_message]).to include('Connection failed for ICN')
        end

        expect { service.get_appointment(appointment_id:) }
          .to raise_error(StandardError)
      end

      it 'sanitizes referral numbers from error message' do
        expect(Rails.logger).to receive(:error) do |_msg, context|
          expect(context[:error_message]).not_to include('REF-12345')
          expect(context[:error_message]).not_to include('VA0000005681')
          expect(context[:error_message]).to include('[REFERRAL_REDACTED]')
        end

        expect { service.get_appointment(appointment_id:) }
          .to raise_error(StandardError)
      end

      it 're-raises the error after logging' do
        expect { service.get_appointment(appointment_id:) }
          .to raise_error(StandardError, error_message)
      end
    end
  end

  describe 'get_appointments' do
    context 'when requesting appointments for a logged in user' do
      let(:successful_appt_response) do
        double('Response', status: 200, body: { 'count' => 1,
                                                'appointments' => [
                                                  {
                                                    'id' => appointment_id,
                                                    'state' => 'booked',
                                                    'patientId' => icn
                                                  }
                                                ] },
                           response_headers:)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(successful_appt_response)
      end
    end

    context 'when the endpoint fails to return appointments' do
      let(:failed_appt_response) do
        double('Response', status: 500, body: 'Unknown service exception',
                           response_headers:)
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, failed_appt_response.status,
                                                        failed_appt_response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'throws exception' do
        expect { service.get_appointments }.to raise_error(Common::Exceptions::BackendServiceException,
                                                           /VA900/)
      end
    end

    context 'when response contains error field' do
      let(:error_response) do
        double('Response', status: 200, body: { error: 'conflict',
                                                'count' => 0,
                                                'appointments' => [] },
                           response_headers:)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(error_response)
        allow(Rails.logger).to receive(:warn)
        # Mock the trace ID in RequestStore since middleware doesn't run in unit tests
        RequestStore.store['eps_trace_id'] = 'test-trace-id-123'
      end

      it 'raises Eps::ServiceException' do
        expect { service.get_appointments }
          .to raise_error(Eps::ServiceException)
      end

      it 'logs the error without PII' do
        expected_controller_name = 'VAOS::V2::AppointmentsController'
        expected_station_number = user.va_treatment_facility_ids&.first

        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: EPS appointment error',
          {
            error_type: 'conflict',
            method: 'get_appointments',
            status: 200,
            controller: expected_controller_name,
            station_number: expected_station_number,
            eps_trace_id: 'test-trace-id-123'
          }
        )

        expect { service.get_appointments }
          .to raise_error(Eps::ServiceException)
      end
    end

    context 'when an unexpected error occurs' do
      let(:error_message) { 'Timeout error for patient ICN 9876543210V654321 referral_number: VA0000012345' }
      let(:unexpected_error) { StandardError.new(error_message) }

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(unexpected_error)
        allow(Rails.logger).to receive(:error)
        RequestStore.store['eps_trace_id'] = 'test-trace-id-456'
      end

      it 'logs the error with sanitized PII and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: EPS unexpected error',
          hash_including(
            service: 'EPS',
            method: 'get_appointments',
            error_class: 'StandardError'
          )
        )

        expect { service.get_appointments }
          .to raise_error(StandardError, error_message)
      end

      it 'sanitizes PII from error message' do
        expect(Rails.logger).to receive(:error) do |_msg, context|
          expect(context[:error_message]).not_to include('9876543210V654321')
          expect(context[:error_message]).not_to include('VA0000012345')
        end

        expect { service.get_appointments }
          .to raise_error(StandardError)
      end
    end
  end

  describe 'create_draft_appointment' do
    let(:referral_id) { 'test-referral-id' }
    let(:successful_draft_appt_response) do
      double('Response', status: 200, body: { 'id' => appointment_id,
                                              'state' => 'draft',
                                              'patientId' => icn },
                         response_headers:)
    end

    context 'when creating draft appointment for a given referral_id' do
      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(successful_draft_appt_response)
      end

      it 'returns the appointments scheduled' do
        exp_response = OpenStruct.new(successful_draft_appt_response.body)

        expect(service.create_draft_appointment(referral_id:)).to eq(exp_response)
      end
    end

    context 'when the endpoint fails' do
      let(:failed_response) do
        double('Response', status: 500, body: 'Unknown service exception',
                           response_headers:)
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, failed_response.status,
                                                        failed_response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'throws exception' do
        expect do
          service.create_draft_appointment(referral_id:)
        end.to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end

    context 'when response contains error field' do
      let(:error_response) do
        double('Response', status: 200, body: { 'id' => appointment_id,
                                                'state' => 'draft',
                                                'patientId' => icn,
                                                'error' => 'conflict' },
                           response_headers:)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(error_response)
        allow(Rails.logger).to receive(:warn)
        # Mock the trace ID in RequestStore since middleware doesn't run in unit tests
        RequestStore.store['eps_trace_id'] = 'test-trace-id-123'
      end

      it 'raises Eps::ServiceException' do
        expect { service.create_draft_appointment(referral_id:) }
          .to raise_error(Eps::ServiceException)
      end

      it 'logs the error without PII' do
        expected_controller_name = 'VAOS::V2::AppointmentsController'
        expected_station_number = user.va_treatment_facility_ids&.first

        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: EPS appointment error',
          {
            error_type: 'conflict',
            method: 'create_draft_appointment',
            status: 200,
            controller: expected_controller_name,
            station_number: expected_station_number,
            eps_trace_id: 'test-trace-id-123'
          }
        )

        expect { service.create_draft_appointment(referral_id:) }
          .to raise_error(Eps::ServiceException)
      end
    end

    context 'when an unexpected error occurs' do
      let(:error_message) { 'Draft creation failed: referralNumber="ref-999" for ICN 5555555555V555555' }
      let(:unexpected_error) { RuntimeError.new(error_message) }

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(unexpected_error)
        allow(Rails.logger).to receive(:error)
        RequestStore.store['eps_trace_id'] = 'test-trace-id-789'
      end

      it 'logs the error with sanitized PII and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: EPS unexpected error',
          hash_including(
            service: 'EPS',
            method: 'create_draft_appointment',
            error_class: 'RuntimeError',
            eps_trace_id: 'test-trace-id-789'
          )
        )

        expect { service.create_draft_appointment(referral_id:) }
          .to raise_error(RuntimeError, error_message)
      end

      it 'includes backtrace in logged context' do
        expect(Rails.logger).to receive(:error) do |_msg, context|
          expect(context[:backtrace]).to be_present
          expect(context[:backtrace]).to be_a(Array)
        end

        expect { service.create_draft_appointment(referral_id:) }
          .to raise_error(RuntimeError)
      end
    end
  end

  describe '#submit_appointment' do
    let(:valid_params) do
      {
        network_id: 'network-123',
        provider_service_id: 'provider-456',
        slot_ids: ['slot-789'],
        referral_number: 'REF-001'
      }
    end

    context 'with valid parameters' do
      let(:successful_response) do
        double('Response', status: 200, body: { 'id' => appointment_id,
                                                'state' => 'draft',
                                                'patientId' => icn },
                           response_headers:)
      end

      it 'submits the appointment successfully' do
        expected_payload = {
          network_id: valid_params[:network_id],
          provider_service_id: valid_params[:provider_service_id],
          slot_ids: valid_params[:slot_ids],
          referral: {
            referral_number: valid_params[:referral_number]
          }
        }

        redis_client = instance_double(Eps::RedisClient)
        allow(Eps::RedisClient).to receive(:new).and_return(redis_client)
        expect(redis_client).to receive(:store_appointment_data).with(
          uuid: user.account_uuid,
          appointment_id:,
          email: user.email
        )

        expect(Eps::AppointmentStatusJob).to receive(:perform_async).with(
          user.account_uuid,
          appointment_id.last(4)
        )

        path = "/#{config.base_path}/appointments/#{appointment_id}/submit"
        expect_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:post, path, expected_payload, kind_of(Hash))
          .and_return(successful_response)

        exp_response = OpenStruct.new(successful_response.body)

        expect(service.submit_appointment(appointment_id, valid_params)).to eq(exp_response)
      end

      it 'includes additional patient attributes when provided' do
        patient_attributes = { name: 'John Doe', email: 'john@example.com' }
        params_with_attributes = valid_params.merge(additional_patient_attributes: patient_attributes)

        expected_payload = {
          network_id: valid_params[:network_id],
          provider_service_id: valid_params[:provider_service_id],
          slot_ids: valid_params[:slot_ids],
          referral: {
            referral_number: valid_params[:referral_number]
          },
          additional_patient_attributes: patient_attributes
        }

        path = "/#{config.base_path}/appointments/#{appointment_id}/submit"
        expect_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:post, path, expected_payload, kind_of(Hash))
          .and_return(successful_response)

        service.submit_appointment(appointment_id, params_with_attributes)
      end
    end

    context 'with invalid parameters' do
      it 'raises ArgumentError when appointment_id is nil' do
        expect { service.submit_appointment(nil, valid_params) }
          .to raise_error(ArgumentError, 'appointment_id is required and cannot be blank')
      end

      it 'raises ArgumentError when appointment_id is empty' do
        expect { service.submit_appointment('', valid_params) }
          .to raise_error(ArgumentError, 'appointment_id is required and cannot be blank')
      end

      it 'raises ArgumentError when appointment_id is blank' do
        expect { service.submit_appointment('   ', valid_params) }
          .to raise_error(ArgumentError, 'appointment_id is required and cannot be blank')
      end

      it 'raises ArgumentError when required parameters are missing' do
        invalid_params = valid_params.except(:network_id)

        expect { service.submit_appointment(appointment_id, invalid_params) }
          .to raise_error(ArgumentError, /Missing required parameters: network_id/)
      end

      it 'raises ArgumentError when multiple required parameters are missing' do
        invalid_params = valid_params.except(:network_id, :provider_service_id)

        expect { service.submit_appointment(appointment_id, invalid_params) }
          .to raise_error(ArgumentError, /Missing required parameters: network_id, provider_service_id/)
      end
    end

    context 'when API returns an error' do
      let(:response) do
        double('Response', status: 500, body: 'Unknown service exception',
                           response_headers:)
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, response.status, response.body)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(exception)
      end

      it 'returns the error response' do
        expect do
          service.submit_appointment(appointment_id, valid_params)
        end.to raise_error(Common::Exceptions::BackendServiceException, /VA900/)
      end
    end

    context 'when response contains error field' do
      let(:error_response) do
        double('Response', status: 200, body: { 'id' => appointment_id,
                                                'state' => 'submitted',
                                                'patientId' => icn,
                                                'error' => 'conflict' },
                           response_headers:)
      end

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_return(error_response)
        allow(Rails.logger).to receive(:warn)
        # Mock the trace ID in RequestStore since middleware doesn't run in unit tests
        RequestStore.store['eps_trace_id'] = 'test-trace-id-123'
      end

      it 'raises Eps::ServiceException' do
        expect { service.submit_appointment(appointment_id, valid_params) }
          .to raise_error(Eps::ServiceException)
      end

      it 'logs the error without PII' do
        expected_controller_name = 'VAOS::V2::AppointmentsController'
        expected_station_number = user.va_treatment_facility_ids&.first

        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: EPS appointment error',
          {
            error_type: 'conflict',
            method: 'submit_appointment',
            status: 200,
            controller: expected_controller_name,
            station_number: expected_station_number,
            eps_trace_id: 'test-trace-id-123'
          }
        )

        expect { service.submit_appointment(appointment_id, valid_params) }
          .to raise_error(Eps::ServiceException)
      end
    end

    context 'when an unexpected error occurs' do
      let(:error_message) { 'Submit failed for REF-789 patient 1111111111V111111' }
      let(:unexpected_error) { StandardError.new(error_message) }

      before do
        allow_any_instance_of(VAOS::SessionService).to receive(:perform).and_raise(unexpected_error)
        allow(Rails.logger).to receive(:error)
        RequestStore.store['eps_trace_id'] = 'test-trace-id-submit'
      end

      it 'logs the error with sanitized PII and re-raises' do
        expect(Rails.logger).to receive(:error).with(
          'Community Care Appointments: EPS unexpected error',
          hash_including(
            service: 'EPS',
            method: 'submit_appointment',
            error_class: 'StandardError',
            eps_trace_id: 'test-trace-id-submit'
          )
        )

        expect { service.submit_appointment(appointment_id, valid_params) }
          .to raise_error(StandardError, error_message)
      end
    end
  end

  describe '#sanitize_error_message' do
    it 'removes ICN from error message' do
      message = 'Error for patient ICN 1234567890V123456'
      sanitized = service.send(:sanitize_error_message, message)

      expect(sanitized).not_to include('1234567890V123456')
      expect(sanitized).to include('Error for patient ICN')
    end

    it 'removes multiple ICNs from error message' do
      message = 'ICN 1234567890V123456 and 9876543210V654321 failed'
      sanitized = service.send(:sanitize_error_message, message)

      expect(sanitized).not_to include('1234567890V123456')
      expect(sanitized).not_to include('9876543210V654321')
    end

    it 'removes VA-format referral numbers' do
      message = 'Referral VA0000005681 not found'
      sanitized = service.send(:sanitize_error_message, message)

      expect(sanitized).not_to include('VA0000005681')
      expect(sanitized).to include('[REFERRAL_REDACTED]')
    end

    it 'removes REF-format referral numbers (case insensitive)' do
      message = 'Error with REF-12345 and ref-67890'
      sanitized = service.send(:sanitize_error_message, message)

      expect(sanitized).not_to include('REF-12345')
      expect(sanitized).not_to include('ref-67890')
      expect(sanitized.scan('[REFERRAL_REDACTED]').count).to eq(2)
    end

    it 'removes referralNumber parameter values' do
      message = 'Failed: referralNumber=REF-12345'
      sanitized = service.send(:sanitize_error_message, message)

      expect(sanitized).not_to include('REF-12345')
      expect(sanitized).to include('referralNumber=[REFERRAL_REDACTED]')
    end

    it 'removes referral_number parameter values' do
      message = 'Error: referral_number: "VA0000012345"'
      sanitized = service.send(:sanitize_error_message, message)

      expect(sanitized).not_to include('VA0000012345')
      expect(sanitized).to include('[REFERRAL_REDACTED]')
    end

    it 'handles nil message' do
      sanitized = service.send(:sanitize_error_message, nil)
      expect(sanitized).to be_nil
    end

    it 'removes all PII from complex error message' do
      message = 'Connection failed for ICN 1234567890V123456 with referralNumber=REF-12345 and ' \
                'referral VA0000005681 plus ICN 9876543210V654321'
      sanitized = service.send(:sanitize_error_message, message)

      expect(sanitized).not_to include('1234567890V123456')
      expect(sanitized).not_to include('9876543210V654321')
      expect(sanitized).not_to include('REF-12345')
      expect(sanitized).not_to include('VA0000005681')
      expect(sanitized).to include('Connection failed for ICN')
    end
  end
end
