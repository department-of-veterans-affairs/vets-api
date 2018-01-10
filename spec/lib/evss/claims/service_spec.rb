# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Claims::Service do
  let(:current_user) { create(:evss_user) }
  let(:claims_service) { described_class.new(current_user) }

  subject { claims_service }

  context 'with headers' do
    let(:evss_id) { 189_625 }

    it 'should get claims' do
      VCR.use_cassette('evss/claims/claims_client', VCR::MATCH_EVERYTHING) do
        response = subject.all_claims
        expect(response).to be_success
      end
    end

    it 'should get a claim by id' do
      VCR.use_cassette('evss/claims/claim_client', record: :once) do
        subject.find_claim_by_id('600118851')
      end
    end

    it 'should post a 5103 waiver' do
      VCR.use_cassette('evss/claims/set_5103_waiver_client', VCR::MATCH_EVERYTHING) do
        response = subject.request_decision(evss_id)
        expect(response).to be_success
      end
    end
  end
end
