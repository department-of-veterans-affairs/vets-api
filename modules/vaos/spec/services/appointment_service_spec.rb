# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentService do
  let(:user) { build(:user, :mhv) }

  # TODO(AJD): placeholder spec all VAOS endpoints are (beta)mocked out for now
  describe '#get_appointments' do
    context 'with one appointment' do
      it 'returns an array of VAOS::Appointment of size 1' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: %i[host path method]) do
          response = subject.get_appointments(user)
          expect(response.size).to eq(1)
        end
      end
    end
  end
end
