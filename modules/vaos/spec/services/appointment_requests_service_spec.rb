# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentRequestsService do
  subject { described_class.for_user(user) }

  let(:user) { build(:user, :mhv) }
  let(:start_date) { Date.parse('2019-08-20') }
  let(:end_date) { Date.parse('2020-08-22') }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#get_requests' do
    context 'without data params' do
      it 'returns an array of size 40' do
        VCR.use_cassette('vaos/appointment_requests/get_requests', match_requests_on: %i[method uri]) do
          response = subject.get_requests
          expect(response[:data].size).to eq(40)
        end
      end
    end

    context 'with data params' do
      it 'returns an array of size 1' do
        VCR.use_cassette('vaos/appointment_requests/get_requests_with_params', match_requests_on: %i[method uri]) do
          response = subject.get_requests(start_date, end_date)
          expect(response[:data].size).to eq(1)
        end
      end
    end
  end
end
