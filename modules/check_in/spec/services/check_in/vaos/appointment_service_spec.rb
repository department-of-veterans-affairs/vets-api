# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::VAOS::AppointmentService do
  subject { described_class }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in_session) { CheckIn::V2::Session.build(data: { uuid: }) }
  let(:patient_icn) { '123' }
  let(:token) { 'test_token' }
  let(:request_id) { SecureRandom.uuid }

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject.build(check_in_session:)).to be_an_instance_of(described_class)
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
      }.to_json
    end
    let(:faraday_response) { double('Faraday::Response') }
    let(:faraday_env) { double('Faraday::Env', status: 200, body: appointments_response) }

    before do
      allow_any_instance_of(V2::Lorota::RedisClient).to receive(:icn).with(uuid:)
                                                                     .and_return(patient_icn)
      allow_any_instance_of(CheckIn::Map::TokenService).to receive(:token)
        .and_return(token)
    end

    context 'when vaos returns successful response' do
      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get)
          .with("/vaos/v1/patients/#{patient_icn}/appointments",
                { start: start_date, end: end_date, statuses: })
          .and_return(faraday_response)
        allow(faraday_response).to receive(:env).and_return(faraday_env)
      end

      it 'returns appointments' do
        svc = subject.build(check_in_session:)
        response = svc.get_appointments(DateTime.parse(start_date).in_time_zone,
                                        DateTime.parse(end_date).in_time_zone,
                                        statuses)
        expect(response).to eq(appointments_response)
      end
    end

    context 'when vaos returns server error' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with('/vaos/v1/patients/123/appointments',
                                                                         { start: start_date, end: end_date,
                                                                           statuses: })
                                                                   .and_raise(exception)
      end

      it 'throws exception' do
        svc = subject.build(check_in_session:)
        expect do
          svc.get_appointments(DateTime.parse(start_date).in_time_zone,
                               DateTime.parse(end_date).in_time_zone,
                               statuses)
        end.to(raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
        end)
      end
    end
  end
end
