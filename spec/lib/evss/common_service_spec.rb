# frozen_string_literal: true
require 'rails_helper'
require 'evss/common_service'
require 'evss/auth_headers'

describe EVSS::CommonService do
  let(:current_user) { FactoryBot.build(:evss_user) }

  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  subject { described_class.new(auth_headers) }

  context 'with headers' do
    let(:participant_id) { 123_456_789 }

    it 'gets a disability rating record' do
      VCR.use_cassette('evss/common/rating_record') do
        response = subject.find_rating_info(current_user.participant_id)
        expect(response).to be_success
      end
    end

    it 'posts to create a user account', run_at: 'Thu, 14 Dec 2017 00:00:32 GMT' do
      VCR.use_cassette('evss/common/create_user_account', VCR::MATCH_EVERYTHING) do
        response = subject.create_user_account
        expect(response).to be_success
      end
    end
  end
end
