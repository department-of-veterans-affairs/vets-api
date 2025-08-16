# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::AppointmentsService do
  let(:auth_manager) { instance_double(TravelClaim::AuthManager) }
  let(:client) { instance_double(TravelClaim::AppointmentsClient) }
  let(:service) { described_class.new(auth_manager) }
  let(:access_token) { 'test-access-token' }

  let(:valid_params) do
    {
      'appointment_date_time' => '2024-01-01T12:45:34.465Z',
      'facility_station_number' => '123',
      'appointment_name' => 'Medical Appointment',
      'appointment_type' => 'Other',
      'is_complete' => false
    }
  end

  let(:successful_api_response) do
    double('faraday_response', body: {
             'data' => [
               {
                 'id' => 'appointment-uuid-123',
                 'appointmentDateTime' => '2024-01-01T12:45:34.465Z',
                 'appointmentName' => 'Medical Appointment',
                 'appointmentType' => 'Other',
                 'facilityId' => 'facility-uuid-456',
                 'facilityName' => 'Test Facility',
                 'isCompleted' => false
               }
             ]
           })
  end

  before do
    allow(service).to receive(:client).and_return(client)
  end

  describe '#find_or_create_appointment' do
    context 'when successful' do
      before do
        allow(auth_manager).to receive(:authorize).and_return(access_token)
        allow(client).to receive(:find_or_add).and_return(successful_api_response)
      end

      it 'returns appointment data from API response' do
        result = service.find_or_create_appointment(valid_params)

        expect(result).to eq({
                               data: {
                                 'id' => 'appointment-uuid-123',
                                 'appointmentDateTime' => '2024-01-01T12:45:34.465Z',
                                 'appointmentName' => 'Medical Appointment',
                                 'appointmentType' => 'Other',
                                 'facilityId' => 'facility-uuid-456',
                                 'facilityName' => 'Test Facility',
                                 'isCompleted' => false
                               }
                             })
      end

      it 'calls auth_manager to get access token' do
        expect(auth_manager).to receive(:authorize).and_return(access_token)
        service.find_or_create_appointment(valid_params)
      end

      it 'calls client with access token and params' do
        expect(client).to receive(:find_or_add).with(access_token, valid_params)
        service.find_or_create_appointment(valid_params)
      end
    end

    context 'when validating parameters' do
      it 'raises BadRequest when appointment_date_time is missing' do
        params = valid_params.except('appointment_date_time')
        expect { service.find_or_create_appointment(params) }
          .to raise_error(Common::Exceptions::BadRequest)
      end

      it 'raises BadRequest when facility_station_number is missing' do
        params = valid_params.except('facility_station_number')
        expect { service.find_or_create_appointment(params) }
          .to raise_error(Common::Exceptions::BadRequest)
      end

      it 'raises BadRequest when appointment_name is too short' do
        params = valid_params.merge('appointment_name' => 'Hi')
        expect { service.find_or_create_appointment(params) }
          .to raise_error(Common::Exceptions::BadRequest)
      end

      it 'raises BadRequest when appointment_date_time is invalid format' do
        params = valid_params.merge('appointment_date_time' => 'invalid-date')
        expect { service.find_or_create_appointment(params) }
          .to raise_error(Common::Exceptions::BadRequest)
      end
    end

    context 'when API returns empty response' do
      before do
        allow(auth_manager).to receive(:authorize).and_return(access_token)
        allow(client).to receive(:find_or_add).and_return(
          double('faraday_response', body: { 'data' => [] })
        )
      end

      it 'raises BackendServiceException' do
        expect { service.find_or_create_appointment(valid_params) }
          .to raise_error(Common::Exceptions::BackendServiceException)
      end
    end

    context 'when API returns nil data' do
      before do
        allow(auth_manager).to receive(:authorize).and_return(access_token)
        allow(client).to receive(:find_or_add).and_return(
          double('faraday_response', body: { 'data' => nil })
        )
      end

      it 'raises BackendServiceException' do
        expect { service.find_or_create_appointment(valid_params) }
          .to raise_error(Common::Exceptions::BackendServiceException)
      end
    end

    context 'when timeout occurs' do
      before do
        allow(auth_manager).to receive(:authorize).and_return(access_token)
        allow(client).to receive(:find_or_add).and_raise(Faraday::TimeoutError)
      end

      it 'raises GatewayTimeout exception' do
        expect { service.find_or_create_appointment(valid_params) }
          .to raise_error(Common::Exceptions::GatewayTimeout)
      end
    end

    context 'when general error occurs' do
      before do
        allow(auth_manager).to receive(:authorize).and_return(access_token)
        allow(client).to receive(:find_or_add).and_raise(StandardError, 'Something went wrong')
      end

      it 'raises BackendServiceException' do
        expect { service.find_or_create_appointment(valid_params) }
          .to raise_error(Common::Exceptions::BackendServiceException)
      end
    end
  end
end
