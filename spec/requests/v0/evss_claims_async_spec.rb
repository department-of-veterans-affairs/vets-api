# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::EVSSClaimsAsync', type: :request do
  include SchemaMatchers

  let(:user) { create(:user, :loa3) }
  let(:evss_user) { create(:evss_user) }
  let(:claim) { create(:evss_claim, user_uuid: user.uuid) }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'for a user without evss attrs' do
    let(:user) { create(:user, :loa3, edipi: nil) }

    it 'returns a 403' do
      sign_in_as(user)
      get '/v0/evss_claims_async'
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe '#index (all user claims) is polled' do
    it 'returns empty result, kicks off job, returns full result when job is completed' do
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

    it 'uses camel-inflection and returns empty result, kicks off job, returns full result when job is completed' do
      # initial request
      sign_in_as(evss_user)
      get '/v0/evss_claims_async', headers: inflection_header
      expect(response).to match_camelized_response_schema('evss_claims_async')
      expect(JSON.parse(response.body)['data']).to eq([])
      expect(JSON.parse(response.body)['meta']['syncStatus']).to eq 'REQUESTED'
      # run job
      VCR.use_cassette('evss/claims/claims') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      end
      # subsequent request
      get '/v0/evss_claims_async', headers: inflection_header
      expect(response).to match_camelized_response_schema('evss_claims_async')
      expect(JSON.parse(response.body)['data']).not_to be_empty
      expect(JSON.parse(response.body)['meta']['syncStatus']).to eq 'SUCCESS'
    end
  end

  describe '#show (single claim) is polled' do
    let!(:claim) do
      create(:evss_claim, id: 1, evss_id: 600_117_255,
                          user_uuid: user.uuid)
    end

    it 'returns claim from DB, kicks off job, returns updated claim when job is completed' do
      # initial request
      sign_in_as(evss_user)
      get '/v0/evss_claims_async/600117255'
      expect(response).to match_response_schema('evss_claim_async')
      expect(JSON.parse(response.body)['data']['type']).to eq 'evss_claims'
      expect(JSON.parse(response.body)['data']['attributes']['phase_change_date']).to eq '2012-08-10'
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      # run job
      VCR.use_cassette('evss/claims/claim_with_docs') do
        EVSS::UpdateClaimFromRemoteJob.new.perform(user.uuid, claim.id)
      end
      # subsequent request
      get '/v0/evss_claims_async/600117255'
      expect(response).to match_response_schema('evss_claim_async')
      expect(JSON.parse(response.body)['data']['attributes']['phase_change_date']).to eq '2017-11-01'
      expect(JSON.parse(response.body)['data']['type']).to eq 'evss_claims'
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
    end

    it 'uses camel-inflection and returns claim from DB, kicks off job, returns updated claim when job is completed' do
      # initial request
      sign_in_as(evss_user)
      get '/v0/evss_claims_async/600117255', headers: inflection_header
      expect(response).to match_camelized_response_schema('evss_claim_async')
      expect(JSON.parse(response.body)['data']['type']).to eq 'evss_claims'
      expect(JSON.parse(response.body)['data']['attributes']['phaseChangeDate']).to eq '2012-08-10'
      expect(JSON.parse(response.body)['meta']['syncStatus']).to eq 'REQUESTED'
      # run job
      VCR.use_cassette('evss/claims/claim_with_docs') do
        EVSS::UpdateClaimFromRemoteJob.new.perform(user.uuid, claim.id)
      end
      # subsequent request
      get '/v0/evss_claims_async/600117255', headers: inflection_header
      expect(response).to match_camelized_response_schema('evss_claim_async')
      expect(JSON.parse(response.body)['data']['attributes']['phaseChangeDate']).to eq '2017-11-01'
      expect(JSON.parse(response.body)['data']['type']).to eq 'evss_claims'
      expect(JSON.parse(response.body)['meta']['syncStatus']).to eq 'SUCCESS'
    end

    it 'user cannot access claim of another user' do
      sign_in_as(user)
      create(:evss_claim, id: 2, evss_id: 189_625,
                          user_uuid: 'xyz')
      # check tagging of EVSSClaimsAsyncController.show RecordNotFound error
      allow(Sentry).to receive(:set_tags)
      expect(Sentry).to receive(:set_tags).with(team: 'benefits-memorial-1')

      VCR.use_cassette('evss/claims/claims') do
        get '/v0/evss_claims_async/2'
      end

      expect(response).to have_http_status(:not_found)
    end
  end
end
