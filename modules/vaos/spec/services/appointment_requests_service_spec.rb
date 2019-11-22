# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentRequestsService do
  subject { described_class.for_user(user) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#post_request' do
    context 'with valid creation attributes from factory' do
      let(:user) { build(:user, :vaos) }
      let(:appointment_request_params) { build(:appointment_request_form, :creation, user: user).params }

      it 'creates a new appointment request' do
        VCR.use_cassette('vaos/appointment_requests/post_request', record: :new_episodes) do
          response = subject.post_request(appointment_request_params)
          expect(response[:data].unique_id).to eq('8a4886886e4c8e22016e92be77cb00f9')
          expect(response[:data].appointment_request_detail_code).to be_empty
        end
      end
    end
  end

  describe 'put_request' do
    context 'with valid cancelation attributes from factory' do
      let(:user) { build(:user, :vaos) }
      let(:id) { '8a4886886e4c8e22016e92be77cb00f9' }
      let(:date) { Time.zone.parse('2019-11-22 10:53:05 +0000') }
      let(:created_date) { '11/22/2019 05:53:0' }
      let(:last_access_date) { nil }
      let(:last_updated_date) { '11/22/2019 05:53:06' }
      let(:appointment_request_params) do
        build(
          :appointment_request_form,
          :cancelation,
          user: user,
          id: id,
          date: date,
          created_date: created_date,
          last_access_date: last_access_date,
          last_updated_date:
          last_updated_date
        ).params
      end

      it 'cancels a pending appointment request' do
        VCR.use_cassette('vaos/appointment_requests/put_request', record: :new_episodes) do
          response = subject.put_request(id, appointment_request_params)
          expect(response[:data].unique_id).to eq('8a4886886e4c8e22016e92be77cb00f9')
          expect(response[:data].appointment_request_detail_code.first[:created_date])
            .to eq('11/22/2019 08:27:58')
        end
      end
    end
  end

  describe '#get_requests' do
    let(:user) { build(:user, :mhv) }
    let(:start_date) { Date.parse('2019-08-20') }
    let(:end_date) { Date.parse('2020-08-22') }

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
