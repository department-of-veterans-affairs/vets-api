# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Claims::Service do
  let(:current_user) { create(:evss_user) }
  let(:claims_service) { described_class.new(current_user) }

  subject { claims_service }

  context 'with headers' do
    let(:evss_id) { 189_625 }

    it 'should get claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
      VCR.use_cassette('evss/claims/claims_client', VCR::MATCH_EVERYTHING) do
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
