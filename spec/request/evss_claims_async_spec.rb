# frozen_string_literal: true

require 'rails_helper'
require 'evss/request_decision'

RSpec.describe 'EVSS Claims management', type: :request do
  include SchemaMatchers

  let(:user) { create(:user, :loa3) }
  let(:evss_user) { create(:evss_user) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }

  context 'for a user without evss attrs' do
    before do
      profile = build(:mvi_profile, edipi: nil)
      stub_mvi(profile)
    end

    it 'returns a 403' do
      sign_in_as(user)
      get '/v0/evss_claims_async'
      expect(response).to have_http_status(:forbidden)
    end
  end

  context '#index (all user claims) is polled' do
    it 'returns empty result, kicks off job, retuns full result when job is completed' do
      # initial request
      sign_in_as(evss_user)
      get '/v0/evss_claims_async'
      expect(response).to match_response_schema('evss_claims_async')
      expect(JSON.parse(response.body)['data']).to eq([])
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      # run job
      VCR.use_cassette('evss/claims/claims') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      end
      # subsequent request
      get '/v0/evss_claims_async'
      expect(response).to match_response_schema('evss_claims_async')
      expect(JSON.parse(response.body)['data']).not_to be_empty
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
    end
  end

  context '#show (single claim) is polled' do
    let!(:claim) do
      FactoryBot.create(:evss_claim, id: 1, evss_id: 600_118_851,
                                     user_uuid: user.uuid)
    end

    it 'returns claim from DB, kicks off job, returns updated claim when job is completed' do
      # initial request
      sign_in_as(evss_user)
      get '/v0/evss_claims_async/600118851'
      expect(response).to match_response_schema('evss_claim_async')
      expect(JSON.parse(response.body)['data']['type']).to eq 'evss_claims'
      expect(JSON.parse(response.body)['data']['attributes']['phase_change_date']).to eq '2012-08-10'
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      # run job
      VCR.use_cassette('evss/claims/claim') do
        EVSS::UpdateClaimFromRemoteJob.new.perform(user.uuid, claim.id)
      end
      # subsequent request
      get '/v0/evss_claims_async/600118851'
      expect(response).to match_response_schema('evss_claim_async')
      expect(JSON.parse(response.body)['data']['attributes']['phase_change_date']).to eq '2017-12-08'
      expect(JSON.parse(response.body)['data']['type']).to eq 'evss_claims'
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
    end

    it 'user cannot access claim of another user' do
      sign_in_as(user)
      FactoryBot.create(:evss_claim, id: 2, evss_id: 189_625,
                                     user_uuid: 'xyz')
      get '/v0/evss_claims_async/2'
      expect(response).to have_http_status(:not_found)
    end
  end
end
