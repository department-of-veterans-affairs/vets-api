# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::VAOS::AppointmentService do
  subject { described_class.build(check_in_session:) }

  let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
  let(:check_in_session) { CheckIn::V2::Session.build(data: { uuid: }) }
  let(:patient_icn) { '123' }
  let(:token) { 'test_token' }
  let(:request_id) { SecureRandom.uuid }

  describe '.build' do
    it 'returns an instance of Service' do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe '#get_appointments' do
    let(:start_date) { DateTime.parse('2023-11-10T17:12:30Z').in_time_zone }
    let(:end_date) { DateTime.parse('2023-12-12T17:12:30Z').in_time_zone }
    let(:token) { 'test-token-123' }

    before do
      allow_any_instance_of(V2::Lorota::RedisClient).to receive(:icn).with(uuid:)
                                                                     .and_return(patient_icn)
      allow_any_instance_of(CheckIn::Map::TokenService).to receive(:token)
        .and_return(token)
    end

    context 'when vaos returns successful response' do
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
        }
      end
      let(:faraday_response) { double('Faraday::Response') }
      let(:faraday_env) { double('Faraday::Env', status: 200, body: appointments_response.to_json) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get)
          .with("/vaos/v1/patients/#{patient_icn}/appointments", { start: start_date, end: end_date })
          .and_return(faraday_response)
        allow(faraday_response).to receive(:env).and_return(faraday_env)
      end

      it 'returns appointments' do
        response = subject.get_appointments(start_date, end_date)

        expect(response).to eq(appointments_response.with_indifferent_access)
      end
    end

    context 'when vaos returns server error' do
      let(:resp) { Faraday::Response.new(body: { error: 'Internal server error' }, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:get).with('/vaos/v1/patients/123/appointments',
                                                                         { start: start_date, end: end_date })
                                                                   .and_raise(exception)
      end

      it 'throws exception' do
        expect do
          subject.get_appointments(start_date, end_date)
        end.to(raise_error do |error|
          expect(error).to be_a(Common::Exceptions::BackendServiceException)
        end)
      end
    end
  end
end
