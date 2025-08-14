# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TravelClaim::AppointmentsClient do
  let(:client) { described_class.new }
  let(:access_token) { 'test-access-token' }
  let(:params) do
    {
      'appointment_date_time' => '2024-01-01T12:45:34.465Z',
      'facility_station_number' => '123',
      'appointment_name' => 'Medical Appointment',
      'appointment_type' => 'Other',
      'is_complete' => false
    }
  end

  describe '#find_or_add' do
    let(:expected_request_body) do
      {
        appointmentDateTime: '2024-01-01T12:45:34.465Z',
        facilityStationNumber: '123',
        appointmentName: 'Medical Appointment',
        appointmentType: 'Other',
        isComplete: false
      }
    end

    let(:successful_response_body) do
      {
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
      }
    end

    context 'when successful' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post)
          .with('api/v3/appointments/find-or-add')
          .and_return(
            double('response', body: successful_response_body, status: 200)
          )
      end

      it 'makes POST request to v3 find-or-add endpoint' do
        connection_mock = double('connection')
        request_mock = double('request', headers: {})

        allow(client).to receive(:connection).and_return(connection_mock)
        allow(connection_mock).to receive(:post).with('api/v3/appointments/find-or-add')
                                                .and_yield(request_mock)
                                                .and_return(
                                                  double('response', body: successful_response_body)
                                                )

        expect(request_mock.headers).to receive(:[]=).with('Authorization', "Bearer #{access_token}")
        expect(request_mock.headers).to receive(:[]=).with('X-Correlation-ID', anything)
        expect(request_mock.headers).to receive(:merge!).with(anything)
        expect(request_mock).to receive(:body=).with(expected_request_body.to_json)

        client.find_or_add(access_token, params)
      end

      it 'transforms parameters correctly' do
        request_body = client.send(:build_request_body, params)
        expect(request_body).to eq(expected_request_body)
      end

      it 'uses default appointment name when not provided' do
        params_without_name = params.except('appointment_name')
        request_body = client.send(:build_request_body, params_without_name)
        expect(request_body[:appointmentName]).to eq('Medical Appointment')
      end

      it 'uses default appointment type when not provided' do
        params_without_type = params.except('appointment_type')
        request_body = client.send(:build_request_body, params_without_type)
        expect(request_body[:appointmentType]).to eq('Other')
      end

      it 'uses default is_complete when not provided' do
        params_without_complete = params.except('is_complete')
        request_body = client.send(:build_request_body, params_without_complete)
        expect(request_body[:isComplete]).to be(false)
      end
    end

    context 'when measuring performance' do
      it 'logs to StatsD' do
        allow_any_instance_of(Faraday::Connection).to receive(:post)
          .and_return(double('response', body: successful_response_body))

        expect(StatsD).to receive(:measure)
          .with('check_in.travel_claim.appointments.response_time', anything, tags: ['travel_claim:find_or_add'])

        client.find_or_add(access_token, params)
      end
    end
  end
end
