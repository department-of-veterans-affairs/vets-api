# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::VAOS::AppointmentService do
  subject { described_class.new(patient_icn:) }

  let(:patient_icn) { '123' }
  let(:token) { 'test_token' }
  let(:request_id) { SecureRandom.uuid }

  describe '#initialize' do
    it 'returns an instance of service' do
      service_obj = subject
      expect(service_obj).to be_an_instance_of(CheckIn::VAOS::AppointmentService)
      expect(service_obj.token_service).to be_an_instance_of(CheckIn::Map::TokenService)
    end
  end

  describe '#perform' do
    let(:token) { 'test-token-123' }
    let(:start_date) { '2023-11-10T17:12:30Z' }
    let(:end_date) { '2023-12-12T17:12:30Z' }
    let(:statuses) { 'confirmed' }
    let(:appointments_response) do
      {
        data: [
          {
            id: '180765',
            kind: 'clinic',
            status: 'booked',
            patientIcn: 'icn',
            locationId: '983GC',
            clinic: '1081',
            start: '2023-11-02T17:12:30.174Z',
            end: '2023-12-12T17:12:30.174Z',
            minutesDuration: 30
          }
        ]
      }.with_indifferent_access
    end
    let(:faraday_response) { double('Faraday::Response') }
    let(:faraday_env) { double('Faraday::Env', status: 200, body: appointments_response.to_json) }

    context 'when vaos returns successful response' do
      before do
        allow_any_instance_of(CheckIn::Map::TokenService).to receive(:token)
          .and_return(token)
        allow_any_instance_of(Faraday::Connection).to receive(:get).with('/vaos/v1/patients/123/appointments',
                                                                         { start: start_date, end: end_date,
                                                                           statuses: })
                                                                   .and_return(faraday_response)
        allow(faraday_response).to receive(:env).and_return(faraday_env)
      end

      it 'returns appointments' do
        response = subject.get_appointments(DateTime.parse(start_date).in_time_zone,
                                            DateTime.parse(end_date).in_time_zone,
                                            statuses)
        expect(response).to eq(appointments_response)
      end
    end

    context 'when vaos returns server error' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(CheckIn::Map::TokenService).to receive(:token)
          .and_return(token)
        allow_any_instance_of(Faraday::Connection).to receive(:get).with('/vaos/v1/patients/123/appointments',
                                                                         { start: start_date, end: end_date,
                                                                           statuses: })
                                                                   .and_raise(exception)
      end

      it 'throws exception' do
        expect do
          subject.get_appointments(DateTime.parse(start_date).in_time_zone,
                                   DateTime.parse(end_date).in_time_zone,
                                   statuses)
        end.to(raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
        end)
      end
    end
  end
end
