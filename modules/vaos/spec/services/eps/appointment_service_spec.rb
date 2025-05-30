# frozen_string_literal: true

require 'rails_helper'

describe Eps::AppointmentService do
  subject(:service) { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234', icn:) }
  let(:config) { instance_double(Eps::Configuration) }
  let(:headers) { { 'Authorization' => 'Bearer token123' } }
  let(:response_headers) { { 'Content-Type' => 'application/json' } }

  let(:appointment_id) { 'appointment-123' }
  let(:icn) { '123ICN' }

  before do
    allow(config).to receive_messages(base_path: 'api/v1', mock_enabled?: false, api_url: 'https://api.wellhive.com')
    allow_any_instance_of(Eps::BaseService).to receive_messages(config:, headers:)
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
          expect_any_instance_of(VAOS::SessionService).to receive(:perform)
            .with(:get, "/#{config.base_path}/appointments/#{appointment_id}?retrieveLatestDetails=true", {}, headers)
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
      end

      it 'raises VAOS::Exceptions::BackendServiceException' do
        expect { service.get_appointment(appointment_id:) }
          .to raise_error(VAOS::Exceptions::BackendServiceException)
      end

      it 'logs the error without PII' do
        expect(Rails.logger).to receive(:warn).with(
          'EPS appointment error detected',
          hash_including(
            error_type: 'conflict',
            method: 'get_appointment',
            status: 200
          )
        )

        expect { service.get_appointment(appointment_id:) }
          .to raise_error(VAOS::Exceptions::BackendServiceException)
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
      end

      it 'raises VAOS::Exceptions::BackendServiceException' do
        expect { service.get_appointments }
          .to raise_error(VAOS::Exceptions::BackendServiceException)
      end

      it 'logs the error without PII' do
        expect(Rails.logger).to receive(:warn).with(
          'EPS appointment error detected',
          hash_including(
            error_type: 'conflict',
            method: 'get_appointments',
            status: 200
          )
        )

        expect { service.get_appointments }
          .to raise_error(VAOS::Exceptions::BackendServiceException)
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

        expect_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:post, "/#{config.base_path}/appointments/#{appointment_id}/submit", expected_payload, kind_of(Hash))
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

        expect_any_instance_of(VAOS::SessionService).to receive(:perform)
          .with(:post, "/#{config.base_path}/appointments/#{appointment_id}/submit", expected_payload, kind_of(Hash))
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
      end

      it 'raises VAOS::Exceptions::BackendServiceException' do
        expect { service.submit_appointment(appointment_id, valid_params) }
          .to raise_error(VAOS::Exceptions::BackendServiceException)
      end

      it 'logs the error without PII' do
        expect(Rails.logger).to receive(:warn).with(
          'EPS appointment error detected',
          hash_including(
            error_type: 'conflict',
            method: 'submit_appointment',
            status: 200
          )
        )

        expect { service.submit_appointment(appointment_id, valid_params) }
          .to raise_error(VAOS::Exceptions::BackendServiceException)
      end
    end
  end
end
