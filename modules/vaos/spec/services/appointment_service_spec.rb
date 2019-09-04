# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentService do
  let(:user) { build(:user, :mhv) }

  # TODO(AJD): placeholder spec all VAOS endpoints are (beta)mocked out for now
  describe '#get_appointments' do
    context 'with no appointments' do
      it 'returns numAppointments as 0' do
        VCR.use_cassette('vaos/appointments/get_appointments', match_requests_on: [:host, :path, :method]) do
          response = subject.get_appointments(user)
          expect(response.status).to eq(200)
        end
      end
    end
  end
end
