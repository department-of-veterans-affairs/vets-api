# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentService do
  let(:user) { build(:user, :mhv) }
  let(:start_date) { Time.now.utc.beginning_of_day + 7.hours }
  let(:end_date) { Time.now.utc.beginning_of_day + 8.hours + 4.months }
  let(:rsa_private) { OpenSSL::PKey::RSA.generate 4096 }

  before { allow(File).to receive(:read).and_return(rsa_private) }

  describe '#get_va_appointments' do
    context 'with 5 va appointments' do
      it 'returns an array of size 5' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[host path method]) do
          response = subject.get_va_appointments(user, start_date, end_date)
          expect(response[:data].size).to eq(5)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/appointments/get_appointments_500', match_requests_on: %i[host path method]) do
          expect{ subject.get_va_appointments(user, start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end

  describe '#get_cc_appointments' do
    context 'with 0 cc appointments' do
      it 'returns an array of size 0' do
        VCR.use_cassette('vaos/appointments/get_cc_appointments_empty', match_requests_on: %i[host path method]) do
          response = subject.get_cc_appointments(user, start_date, end_date)
          expect(response[:data].size).to eq(0)
        end
      end
    end

    context 'when the upstream server returns a 500' do
      it 'raises a backend exception' do
        VCR.use_cassette('vaos/appointments/get_cc_appointments_500', match_requests_on: %i[host path method]) do
          expect{ subject.get_cc_appointments(user, start_date, end_date) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end
  end
end
