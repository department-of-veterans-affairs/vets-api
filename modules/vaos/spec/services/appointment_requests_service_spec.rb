# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentRequestsService do
  subject { described_class.for_user(user) }

  let(:user) { build(:user, :mhv) }
  let(:rsa_private) { OpenSSL::PKey::RSA.generate 4096 }

  # before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_requests' do
    it 'returns an array of size 40' do
      VCR.use_cassette('vaos/appointment_requests/get_requests', match_requests_on: %i[host path method]) do
        response = subject.get_requests
        expect(response[:data].size).to eq(40)
      end
    end
  end

  describe '#put_cancel_request' do
    it 'cancels an appointment' do
      VCR.use_cassette('vaos/appointment_requests/put_cancel_request', record: :new_episodes) do
        request_id = ''
        binding.pry

        response = subject.put_cancel_request(request_id)

        binding.pry
        expect(response[:data].size).to eq(40)
      end
    end
  end
end
