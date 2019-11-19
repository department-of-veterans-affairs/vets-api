# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentService do
  subject { described_class.for_user(user) }

  let(:user) { build(:user, :vaos) }
  let(:start_date) { Time.zone.parse('2019-11-14T07:00:00Z') }
  let(:end_date) { Time.zone.parse('2020-03-14T08:00:00Z') }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#put_cancel_appointment' do
    context 'when appointment cannot be cancelled' do
      let(:request_body) do
        {
          appointment_time: '11/15/19 20:00:00',
          clinic_id: '408',
          cancel_reason: 'whatever',
          cancel_code: '5',
          remarks: nil,
          clinic_name: nil
        }
      end

      it 'returns the bad request with detail in errors' do
        VCR.use_cassette('vaos/appointments/put_cancel_appointment_400', match_requests_on: %i[method uri]) do
          expect { subject.put_cancel_appointment(request_body) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when appointment can be cancelled' do
      let(:request_body) do
        {
          appointment_time: '11/15/2019 13:00:00',
          clinic_id: '437',
          cancel_reason: '5',
          cancel_code: 'PC',
          remarks: '',
          clinic_name: 'CHY OPT VAR1'
        }
      end

      it 'cancels the appointment' do
        VCR.use_cassette('vaos/appointments/put_cancel_appointment', match_requests_on: %i[method uri]) do
          response = subject.put_cancel_appointment(request_body)
          expect(response).to be_an_instance_of(String).and be_empty
        end
      end
    end
  end

  describe '#get_appointments of type va' do
    let(:type) { 'va' }

    context 'with 12 va appointments' do
      it 'returns an array of size 12' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[method uri]) do
          response = subject.get_appointments(type, start_date, end_date)
          expect(response[:data].size).to eq(12)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/appointments/get_appointments_500', match_requests_on: %i[method uri]) do
          expect { subject.get_appointments(type, start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_appointments of type cc' do
    let(:type) { 'cc' }

    context 'with 17 cc appointments' do
      it 'returns an array of size 17' do
        VCR.use_cassette('vaos/appointments/get_cc_appointments', match_requests_on: %i[method uri]) do
          response = subject.get_appointments(type, start_date, end_date)
          expect(response[:data].size).to eq(17)
        end
      end
    end

    context 'with 0 cc appointments' do
      it 'returns an array of size 0' do
        VCR.use_cassette('vaos/appointments/get_cc_appointments_empty', match_requests_on: %i[method uri]) do
          response = subject.get_appointments(type, start_date, end_date)
          expect(response[:data].size).to eq(0)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/appointments/get_cc_appointments_500', match_requests_on: %i[method uri]) do
          expect { subject.get_appointments(type, start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end