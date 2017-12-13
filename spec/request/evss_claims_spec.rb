# frozen_string_literal: true
require 'rails_helper'

require 'evss/request_decision'

RSpec.describe 'EVSS Claims management', type: :request do
  include SchemaMatchers

  let(:user) { create(:user, :loa3) }
  let(:session) { Session.create(uuid: user.uuid) }
  let(:evss_user) { create(:evss_user) }
  let(:evss_session) { Session.create(uuid: evss_user.uuid) }

  context 'for a user without evss attrs' do
    before do
      profile = build(:mvi_profile, edipi: nil)
      stub_mvi(profile)
    end

    it 'returns a 403' do
      get '/v0/evss_claims', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'lists all Claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
    VCR.use_cassette('evss/claims/claims', VCR::MATCH_EVERYTHING) do
      get '/v0/evss_claims', nil, 'Authorization' => "Token token=#{evss_session.token}"
      expect(response).to match_response_schema('evss_claims')
    end
  end

  context 'for a single claim' do
    let!(:claim) do
      FactoryBot.create(:evss_claim, id: 1, evss_id: 600118851,
                                     user_uuid: user.uuid)
    end

    it 'sets 5103 waiver when requesting a decision' do
      expect do
        post '/v0/evss_claims/600118851/request_decision', nil, 'Authorization' => "Token token=#{session.token}"
      end.to change(EVSS::RequestDecision.jobs, :size).by(1)
      expect(response.status).to eq(202)
      expect(JSON.parse(response.body)['job_id']).to eq(EVSS::RequestDecision.jobs.first['jid'])
    end

    it 'shows a single Claim', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      VCR.use_cassette('evss/claims/claim', VCR::MATCH_EVERYTHING) do
        get '/v0/evss_claims/600118851', nil, 'Authorization' => "Token token=#{evss_session.token}"
        expect(response).to match_response_schema('evss_claim')
      end
    end

    it 'user cannot access claim of another user' do
      FactoryBot.create(:evss_claim, id: 2, evss_id: 189_625,
                                     user_uuid: 'xyz')
      get '/v0/evss_claims/2', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:not_found)
    end

    context '5103 waiver has not been submitted yet' do
      before do
        claim.requested_decision = false
        claim.save
      end
      it 'has waiver_submitted set after requesting a decision' do
        expect(claim.requested_decision).to eq(false)
        post '/v0/evss_claims/600118851/request_decision', nil, 'Authorization' => "Token token=#{session.token}"
        expect(claim.reload.requested_decision).to eq(true)
      end
    end
  end
end
