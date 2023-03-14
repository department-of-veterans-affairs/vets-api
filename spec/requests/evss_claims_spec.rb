# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'EVSS Claims management', type: :request do
  include SchemaMatchers

  let(:user) { create(:user, :loa3, edipi: nil) }
  let(:evss_user) { create(:evss_user) }
  let(:inflection_header) { { 'X-Key-Inflection' => 'camel' } }

  context 'for a user without evss attrs' do
    it 'returns a 403' do
      sign_in_as(user)
      profile = build(:mvi_profile, edipi: nil)
      stub_mpi(profile)
      get '/v0/evss_claims'
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'lists all Claims', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
    sign_in_as(evss_user)
    VCR.use_cassette('evss/claims/claims', match_requests_on: %i[uri method body]) do
      get '/v0/evss_claims'
      expect(response).to match_response_schema('evss_claims')
    end
  end

  it 'lists all Claims when camel-inflected', run_at: 'Tue, 12 Dec 2017 03:09:06 GMT' do
    sign_in_as(evss_user)
    VCR.use_cassette('evss/claims/claims', match_requests_on: %i[uri method body]) do
      get '/v0/evss_claims', headers: inflection_header
      expect(response).to match_camelized_response_schema('evss_claims')
    end
  end

  context 'for a single claim' do
    let!(:claim) do
      FactoryBot.create(:evss_claim, id: 1, evss_id: 600_118_851,
                                     user_uuid: user.uuid)
    end

    it 'sets 5103 waiver when requesting a decision' do
      sign_in_as(evss_user)
      expect do
        post '/v0/evss_claims/600118851/request_decision'
      end.to change(EVSS::RequestDecision.jobs, :size).by(1)
      expect(response.status).to eq(202)
      expect(JSON.parse(response.body)['job_id']).to eq(EVSS::RequestDecision.jobs.first['jid'])
    end

    it 'shows a single Claim', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      sign_in_as(evss_user)
      VCR.use_cassette('evss/claims/claim', match_requests_on: %i[uri method body]) do
        get '/v0/evss_claims/600118851'
        expect(response).to match_response_schema('evss_claim')
      end
    end

    it 'shows a single Claim when camel-inflected', run_at: 'Wed, 13 Dec 2017 03:28:23 GMT' do
      sign_in_as(evss_user)
      VCR.use_cassette('evss/claims/claim', match_requests_on: %i[uri method body]) do
        get '/v0/evss_claims/600118851', headers: inflection_header
        expect(response).to match_camelized_response_schema('evss_claim')
      end
    end

    it 'user cannot access claim of another user' do
      sign_in_as(evss_user)
      FactoryBot.create(:evss_claim, id: 2, evss_id: 189_625,
                                     user_uuid: 'xyz')
      # check tagging of EVSSClaimsController.show RecordNotFound error
      allow(Raven).to receive(:tags_context)
      expect(Raven).to receive(:tags_context).with(team: 'benefits-memorial-1')

      get '/v0/evss_claims/2'
      expect(response).to have_http_status(:not_found)
    end

    context '5103 waiver has not been submitted yet' do
      it 'has waiver_submitted set after requesting a decision' do
        sign_in_as(evss_user)
        claim.requested_decision = false
        claim.save

        expect(claim.requested_decision).to eq(false)
        post '/v0/evss_claims/600118851/request_decision'
        expect(claim.reload.requested_decision).to eq(true)
      end
    end
  end
end
