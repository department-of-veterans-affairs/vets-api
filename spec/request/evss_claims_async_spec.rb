# frozen_string_literal: true

require 'rails_helper'
require 'evss/request_decision'

RSpec.describe 'EVSS Claims management', type: :request do
  include SchemaMatchers

  let(:user) { create(:user, :loa3) }
  let(:session) { Session.create(uuid: user.uuid) }
  let(:evss_user) { create(:evss_user) }
  let(:evss_session) { Session.create(uuid: evss_user.uuid) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }

  context 'for a user without evss attrs' do
    before do
      profile = build(:mvi_profile, edipi: nil)
      stub_mvi(profile)
    end

    it 'returns a 403' do
      get '/v0/evss_claims_async', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'returns empty response' do
    get '/v0/evss_claims_async', nil, 'Authorization' => "Token token=#{evss_session.token}"
    expect(response).to match_response_schema('evss_claims_async')
    expect(JSON.parse(response.body)['data']).to eq([])
    expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
  end

  context 'for a single claim' do
    let!(:claim) do
      FactoryBot.create(:evss_claim, id: 1, evss_id: 600_118_851,
                                     user_uuid: user.uuid)
    end

    it 'shows a single Claim' do
      get '/v0/evss_claims_async/600118851', nil, 'Authorization' => "Token token=#{evss_session.token}"
      expect(response).to match_response_schema('evss_claim_async')
      expect(JSON.parse(response.body)['data']['type']).to eq 'evss_claims'
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
    end

    it 'user cannot access claim of another user' do
      FactoryBot.create(:evss_claim, id: 2, evss_id: 189_625,
                                     user_uuid: 'xyz')
      get '/v0/evss_claims_async/2', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:not_found)
    end

    context 'after async processing has finished' do
      before do
        EVSSClaimsRedisHelper.new(user_uuid: user.uuid).cache_collection(status: 'SUCCESS')
        claim
      end
      after do
        EVSSClaimsRedisHelper.new(user_uuid: user.uuid).cache_collection(status: 'REQUESTED')
      end
      it 'returns after async processing has finished' do
        get '/v0/evss_claims_async', nil, 'Authorization' => "Token token=#{evss_session.token}"
        expect(response).to match_response_schema('evss_claims_async')
        expect(JSON.parse(response.body)['data'].count).to eq(1)
        expect(JSON.parse(response.body)['data'][0]['type']).to eq('evss_claims')
        expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
      end
    end
  end
end
