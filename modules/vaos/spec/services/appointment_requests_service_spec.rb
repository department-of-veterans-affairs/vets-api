# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentRequestsService do
  subject { described_class.for_user(user) }

  let(:user) { build(:user, :mhv) }
  let(:start_date) { Date.parse('2019-08-20') }
  let(:end_date) { Date.parse('2020-08-22') }

#  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#post_request' do
    context 'with valid creation attributes from factory' do
      let(:user) { build(:user, :vaos) }
      let(:appointment_request_params) { build(:appointment_request_form, :creation, user: user).params }

      it 'creates a new appointment request' do
        VCR.use_cassette('vaos/appointment_requests/post_request', record: :new_episodes) do
          binding.pry
          response = subject.post_request(appointment_request_params)
          expect(response).to have_http_status(:created)
        end
      end
    end
  end

  describe "put_request" do
    context 'with valid cancelation attributes from factory' do
      let(:user) { build(:user, :vaos) }
      let(:id) { 'banana' }
      let(:appointment_request_params) { build(:appointment_request_form, :cancelation, user: user, id: id).params }

      it 'creates a new appointment request' do
        VCR.use_cassette('vaos/appointment_requests/put_request', record: :new_episodes) do
          binding.pry
          response = subject.put_request(appointment_request_params)
          expect(response).to have_http_status(:success)
        end
      end
    end
  end

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
