# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VirtualAgentClaims', type: :request do
  let(:user) { create(:user, :loa3) }

  describe 'GET /v0/virtual_agent/claim' do
    it 'returns information when most recent open claim is compensation' do
      sign_in_as(user)
      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      expect(JSON.parse(response.body)['data']).to eq nil

      # run job
      VCR.use_cassette('evss/claims/claims') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      end

      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
      expect(JSON.parse(response.body)['data']).to be_kind_of(Array)
      expect(JSON.parse(response.body)['data'].size).to equal(1)
      expect(JSON.parse(response.body)['data']).to include({
                                                             'claim_type' => 'Compensation',
                                                             'claim_status' => 'UNDER REVIEW',
                                                             'filing_date' => '12/08/2017',
                                                             'evss_id' => '600118851'
                                                           })
    end

    it 'returns empty array when no open claims are found' do
      sign_in_as(user)
      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      expect(JSON.parse(response.body)['data']).to eq nil

      # run job
      VCR.use_cassette('evss/claims/claims_trimmed_down') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      end

      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
      expect(JSON.parse(response.body)['data']).to be_kind_of(Array)
      expect(JSON.parse(response.body)['data'].size).to equal(0)
    end

    it 'returns empty array when there are only closed compensation claims' do
      sign_in_as(user)
      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      expect(JSON.parse(response.body)['data']).to eq nil

      # run job
      VCR.use_cassette('evss/claims/claims_historical_compensation') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      end

      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
      expect(JSON.parse(response.body)['data']).to be_kind_of(Array)
      expect(JSON.parse(response.body)['data'].size).to equal(0)
    end

    it 'returns information when there is a more recent non-compensation open claim' do
      sign_in_as(user)
      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      expect(JSON.parse(response.body)['data']).to eq nil

      # run job
      VCR.use_cassette('evss/claims/claims_most_recent_dependent') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      end

      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
      expect(JSON.parse(response.body)['data']).to include({
                                                             'claim_type' => 'Compensation',
                                                             'claim_status' => 'CLAIM RECEIVED',
                                                             'filing_date' => '09/28/2017',
                                                             'evss_id' => '600114693'
                                                           })
    end

    it 'sorts compensation claims by filing date' do
      sign_in_as(user)
      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'REQUESTED'
      expect(JSON.parse(response.body)['data']).to eq nil

      # run job
      VCR.use_cassette('evss/claims/claims_multiple_compensation_claims') do
        EVSS::RetrieveClaimsFromRemoteJob.new.perform(user.uuid)
      end

      get '/v0/virtual_agent/claim'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['meta']['sync_status']).to eq 'SUCCESS'
      expect(JSON.parse(response.body)['data']).to include({
                                                             'claim_type' => 'Compensation',
                                                             'claim_status' => 'UNDER REVIEW',
                                                             'filing_date' => '12/08/2017',
                                                             'evss_id' => '600118851'
                                                           })
    end
  end
end
