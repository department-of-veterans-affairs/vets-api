# frozen_string_literal: true

require 'rails_helper'

describe CheckIn::Map::Client do
  subject { described_class.build }

  describe '.build' do
    it 'returns an instance of described_class' do
      expect(subject).to be_an_instance_of(described_class)
    end
  end

  describe 'extends' do
    it 'extends forwardable' do
      expect(described_class.ancestors).to include(Forwardable)
    end
  end

  describe '#initialize' do
    it 'has settings attribute' do
      expect(subject.settings).to be_a(Config::Options)
    end
  end

  describe '#appointments' do
    let(:jwt_token) { 'test-token' }
    let(:icn) { 'test-patient-icn' }
    let(:query_params) { 'start=2023-11-02T17:12:30.174Z&end=2023-12-12T17:12:30.174Z' }

    context 'when appointments service returns success response' do
      let(:appointments_response) do
        {
          data: [
            {
              id: '180765',
              identifier: [
                {
                  system: 'https://va.gov/Appointment/',
                  value: '413938333130383735'
                }
              ],
              kind: 'clinic',
              status: 'booked',
              serviceType: 'amputation',
              patientIcn: :icn,
              locationId: '983GC',
              clinic: '1081',
              start: '2023-11-02T17:12:30.174Z',
              end: '2023-12-12T17:12:30.174Z',
              minutesDuration: 30,
              extension: {
                preCheckinAllowed: true,
                eCheckinAllowed: true
              }
            }
          ]
        }
      end

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(appointments_response)
      end

      it 'returns appointments data' do
        expect(subject.appointments(token: jwt_token, patient_icn: icn,
                                    query_params:)).to eq(appointments_response)
      end
    end

    context 'when appointments service returns success response takes out https://va.gov' do
      let(:appointments_response) do
        {
          data: [
            {
              id: '180765',
              identifier: [
                {
                  system: 'https://va.gov/Appointment/',
                  value: '413938333130383735'
                }
              ],
              kind: 'clinic',
              status: 'booked',
              serviceType: 'amputation',
              patientIcn: :icn,
              locationId: '983GC',
              clinic: '1081',
              start: '2023-11-02T17:12:30.174Z',
              end: '2023-12-12T17:12:30.174Z',
              minutesDuration: 30,
              extension: {
                preCheckinAllowed: true,
                eCheckinAllowed: true
              }
            }
          ]
        }
      end

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_return(appointments_response)
      end

      it 'strips https://va.gov from any system property in the response' do
        response = subject.appointments(token: jwt_token, patient_icn: icn, query_params:)
        response[:data].each do |appointment|
          appointment[:identifier].each do |identifier|
            expect(identifier[:system]).not_to start_with('https://va.gov')
          end
        end
      end
    end

    context 'when appointments service returns a 500 error response' do
      let(:error_msg) do
        {
          id: '3fa85f64-5717-4562-b3fc-2c963f66afa6',
          code: 0,
          errorCode: 0,
          traceId: 'test-trace-id',
          message: 'test-message',
          detail: 'detailed message'
        }
      end
      let(:resp) { Faraday::Response.new(body: error_msg, status: 500) }
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'returns original error' do
        response = subject.appointments(token: jwt_token, patient_icn: icn, query_params:)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when appointments service returns a 400 error response' do
      let(:resp) do
        Faraday::Response.new(
          body: {  message: 'appointments error message',
                   detail: 'detailed appointments error message' }, status: 400
        )
      end
      let(:exception) { Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body) }

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'returns original error' do
        response = subject.appointments(token: jwt_token, patient_icn: icn, query_params:)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when appointments service returns a 401 error response' do
      let(:resp) do
        Faraday::Response.new(body: 'Unauthorized: authorization information is missing or invalid.', status: 401)
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body)
      end

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'returns original error' do
        response = subject.appointments(token: jwt_token, patient_icn: icn, query_params:)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end

    context 'when appointments service returns a 403 error response' do
      let(:resp) do
        Faraday::Response.new(body: 'Not Authorized: the JWT lacked sufficient grants for the server to
                              fulfill the request.', status: 403)
      end
      let(:exception) do
        Common::Exceptions::BackendServiceException.new(nil, {}, resp.status, resp.body)
      end

      before do
        allow_any_instance_of(Faraday::Connection).to receive(:post).with(anything).and_raise(exception)
      end

      it 'raises exception' do
        response = subject.appointments(token: jwt_token, patient_icn: icn, query_params:)
        expect(response.status).to eq(resp.status)
        expect(response.body).to eq(resp.body)
      end
    end
  end
end
