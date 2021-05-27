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
    context 'when requesting a list of appointments' do
      it 'returns a 200 status with list of appointments' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_200', match_requests_on: %i[method uri],
                                                                      tag: :force_utf8) do
          response = subject.get_appointments(start_date, end_date)

          expect(response[:data].size).to eq(9)
        end
      end
    end

    context '400' do
      it 'raises a 400 error' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_400', match_requests_on: %i[method uri]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context '401' do
      it 'raises a 401 error' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_401', match_requests_on: %i[method uri]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context '403' do
      it 'raises a 403' do
        VCR.use_cassette('vaos/v2/appointments/get_appointments_403', match_requests_on: %i[method uri]) do
          expect { subject.get_appointments(start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
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
        VCR.use_cassette('vaos/v2/appointments/get_appointment_200', match_requests_on: %i[method uri]) do
          response = subject.get_appointment('20029')
          expect(response[:id]).to eq('20029')
          expect(response[:kind]).to eq('telehealth')
          expect(response[:status]).to eq('booked')
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/get_appointment_500', match_requests_on: %i[method uri]) do
          expect { subject.get_appointment('no_such_appointment') }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#update_appointments' do
    context 'when the upstream server returns a 400' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/v2/appointments/put_appointments_400', match_requests_on: %i[method uri]) do
          expect { subject.update_appointment(appt_id: 1121, status: 'cancelled') }
            .to raise_error do |error|
            expect(error).to be_a(Common::Exceptions::BackendServiceException)
            expect(error.status_code).to eq(400)
          end
        end
      end
    end

    context 'when the upstream server successfully updates appointment' do
      it 'returns the updated appointment body' do
        VCR.use_cassette('vaos/v2/appointments/put_appointments_200', match_requests_on: %i[method uri]) do
          response = subject.update_appointment(appt_id: 1121, status: 'cancelled')
          expect(response.status).to eq('cancelled')
        end
      end
    end
  end
end
