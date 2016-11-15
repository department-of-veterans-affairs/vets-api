# frozen_string_literal: true
require 'rails_helper'
require 'evss/claims_service'
require 'evss/auth_headers'

describe EVSS::ClaimsService do
  let(:current_user) { FactoryGirl.create(:loa3_user) }
  let(:auth_headers) do
    EVSS::AuthHeaders.new(current_user).to_h
  end

  subject { described_class.new(auth_headers) }

  context 'with headers' do
    let(:evss_id) { 189_625 }

    it 'should get claims' do
      VCR.use_cassette('evss/claims/claims') do
        response = subject.all_claims
        expect(response).to be_success
      end
    end

    it 'should post a 5103 waiver' do
      VCR.use_cassette('evss/claims/set_5103_waiver') do
        response = subject.request_decision(evss_id)
        expect(response).to be_success
      end
    end
  end
end
