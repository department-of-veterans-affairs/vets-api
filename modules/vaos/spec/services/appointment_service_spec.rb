# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentService do
  let(:user) { build(:user, :mhv) }
  let(:rsa_private) { OpenSSL::PKey::RSA.generate 4096 }

  before { allow(File).to receive(:read).and_return(rsa_private) }

  describe '#get_appointments' do
    context 'with one va appointment and no community care appointments' do
      it 'returns an array of VAOS::Appointment of size 1' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[host path method]) do
          VCR.use_cassette('vaos/appointments/get_cc_appointments_empty', match_requests_on: %i[host path method]) do
            response = subject.get_appointments(user)
            expect(response[:va_appointments].size).to eq(5)
            expect(response[:cc_appointments].size).to eq(0)
          end
        end
      end
    end

    context 'when va appointments succeeds bu cc appointments fails' do
      it 'returns an array of VAOS::Appointment of size 1' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[host path method]) do
          VCR.use_cassette('vaos/appointments/get_cc_appointments_500', match_requests_on: %i[host path method]) do
            response = subject.get_appointments(user)
            expect(response[:va_appointments].size).to eq(5)
            expect(response[:cc_appointments]).to be_nil
            expect(response[:errors]).to eq(
              [{ endpoint: :get_cc_appointments, message: 'the server responded with status 500', status: 500 }]
            )
          end
        end
      end
    end
  end
end
