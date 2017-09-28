# frozen_string_literal: true
require 'rails_helper'

describe EVSS::EVSSCommon::Service do
  let(:current_user) { FactoryGirl.build(:loa3_user) }

  subject { described_class.new(current_user) }

  context 'with a user' do
    let(:participant_id) { 123_456_789 }

    it 'gets a disability rating record' do
      VCR.use_cassette('evss/common/rating_record') do
        response = subject.find_rating_info(participant_id)
        expect(response).to be_success
      end
    end

    it 'posts to create a user account' do
      VCR.use_cassette('evss/common/create_user_account') do
        response = subject.create_user_account
        expect(response).to be_success
      end
    end
  end
end
