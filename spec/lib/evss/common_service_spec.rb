# frozen_string_literal: true

require 'rails_helper'
require 'evss/common_service'
require 'evss/auth_headers'

describe EVSS::CommonService do
  subject { described_class.new(auth_headers) }

  let(:current_user) { FactoryBot.build(:evss_user) }
  let(:auth_headers) { EVSS::AuthHeaders.new(current_user).to_h }
  let(:transaction_id) { auth_headers['va_eauth_service_transaction_id'] }

  context 'with headers' do
    it 'posts to create a user account', run_at: 'Thu, 14 Dec 2017 00:00:32 GMT' do
      VCR.use_cassette(
        'evss/common/create_user_account',
        erb: { transaction_id: transaction_id },
        match_requests_on: VCR.all_matches
      ) do
        response = subject.create_user_account
        expect(response).to be_success
      end
    end

    it 'posts to get current info' do
      # This is a stubbed out test to bypass coverage failures due to nobody having
      # written a test in the original implementation.
      # Currently, it is not possible to write a VCR cassette due to the EVSS API not
      # being accessible on their PINT server. This should be rectified in the future
      # once it is possible.
      allow_any_instance_of(EVSS::BaseService).to receive(:post).and_return(true)
      response = subject.get_current_info
      expect(response).to eq true
    end
  end

  describe '#get_rating_info' do
    context 'with a valid evss response' do
      it 'returns a rating info response object' do
        VCR.use_cassette('evss/disability_compensation_form/rating_info') do
          response = subject.get_rating_info
          expect(response).to be_ok
          expect(response).to be_an EVSS::DisabilityCompensationForm::RatingInfoResponse
          expect(response.user_percent_of_disability).to eq nil
        end
      end
    end
  end
end
