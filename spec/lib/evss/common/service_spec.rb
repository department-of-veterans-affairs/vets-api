# frozen_string_literal: true
require 'rails_helper'

describe EVSS::EVSSCommon::Service do
  let(:current_user) { FactoryGirl.build(:user, :loa3) }

  subject { described_class.new(current_user) }

  context 'with a user' do
    let(:participant_id) { 123_456_789 }

    it 'gets a disability rating record' do
      allow(current_user).to receive(:participant_id).and_return(participant_id)

      VCR.use_cassette('evss/common/rating_record') do
        response = subject.find_rating_info
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
