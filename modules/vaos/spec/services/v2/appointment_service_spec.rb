# frozen_string_literal: true

require 'rails_helper'

describe VAOS::V2::AppointmentsService do
  subject { described_class.new(user) }

  let(:user) { build(:user, :vaos) }
  let(:start_date) { Time.zone.parse('2020-06-02T07:00:00Z') }
  let(:end_date) { Time.zone.parse('2020-07-02T08:00:00Z') }
  let(:id) { '202006031600983000030800000000000000' }
  let(:appointment_id) { 123 }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#post_appointment' do
    let(:request_body) do
      FactoryBot.build(:appointment_form_v2, :eligible).attributes
    end

    context 'when request is valid' do
      it 'returns the created appointment' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments', match_requests_on: %i[method uri]) do
          response = subject.post_appointments(request_body)
          expect(response[:id]).to be_a(String)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/post_appointments_500', match_requests_on: %i[method uri]) do
          expect { subject.post_appointments(request_body) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_appointments' do
    context 'with an appointment' do
      it 'returns an appointment' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments', match_requests_on: %i[method uri]) do
          response = subject.get_appointments(start_date, end_date)
          expect(response[:data].size).to eq(1)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_500', match_requests_on: %i[method uri]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_appointment' do
    context 'with an appointment' do
      it 'returns an appointment' do
        VCR.use_cassette('vaos/v2/appointments/get_appointment', match_requests_on: %i[method uri]) do
          response = subject.get_appointment(appointment_id)
          expect(response[:id]).to eq(id)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/get_appointment_500', match_requests_on: %i[method uri]) do
          expect { subject.get_appointment(appointment_id) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
