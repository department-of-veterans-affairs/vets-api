# frozen_string_literal: true

require 'rails_helper'

describe VAOS::AppointmentRequestsService do
  subject { described_class.for_user(user) }

  let(:user) { build(:user, :vaos) }

  before { allow_any_instance_of(VAOS::UserService).to receive(:session).and_return('stubbed_token') }

  describe '#put_cancel_appointment_request' do
    context 'when appointment_request cannot be cancelled' do
      let(:request_body)  { build(:va_appointment_request) }

      it 'returns the bad request with detail in errors' do
        VCR.use_cassette('vaos/appointment_requests/put_cancel_appointment_request_400', match_requests_on: %i[method uri]) do
          expect { subject.put_cancel_appointment_request(request_body) }.to raise_error(
            Common::Exceptions::BackendServiceException
          )
        end
      end
    end

    context 'when appointment_request can be cancelled' do
      let(:request_body)  { build(:va_appointment_request) }

      it 'cancels the appointment_request' do
        VCR.use_cassette('vaos/appointment_requests/put_cancel_appointment_request', match_requests_on: %i[method uri]) do
          response = subject.put_cancel_appointment_request(request_body)
          expect(response).to be_an_instance_of(String).and be_empty
        end
      end
    end
  end

  describe '#get_requests' do
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
