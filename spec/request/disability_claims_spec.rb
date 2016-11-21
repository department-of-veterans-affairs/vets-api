# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'disability Claims management', type: :request do
  let(:user) { FactoryGirl.create(:loa3_user) }
  let(:session) { Session.create(uuid: user.uuid) }

  context 'for a user without evss attrs' do
    before do
      allow(Mvi).to receive(:find).and_return(
        Mvi.new(
          uuid: 'abc123',
          response: {
            status: 'OK',
            birth_date: '18090212',
            edipi: nil,
            vba_corp_id: '12345678^PI^200CORP^USVBA^A',
            family_name: 'Lincoln',
            gender: 'M',
            given_names: %w(Abraham),
            icn: '1000123456V123456^NI^200M^USVHA^P',
            mhv_ids: ['123456^PI^200MH^USVHA^A'],
            ssn: '272111863',
            active_status: 'active'
          }
        )
      )
    end

    it 'returns a 403' do
      get '/v0/disability_claims', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:forbidden)
    end
  end

  it 'lists all Claims' do
    VCR.use_cassette('evss/claims/claims') do
      get '/v0/disability_claims', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to match_response_schema('disability_claims')
    end
  end

  context 'for a single claim' do
    let!(:claim) do
      FactoryGirl.create(:disability_claim, id: 1, evss_id: 189_625,
                                            user_uuid: user.uuid)
    end

    it 'sets 5103 waiver when requesting a decision' do
      expect do
        post '/v0/disability_claims/189625/request_decision', nil, 'Authorization' => "Token token=#{session.token}"
      end.to change(DisabilityClaim::RequestDecision.jobs, :size).by(1)
      expect(response.status).to eq(202)
      expect(JSON.parse(response.body)['job_id']).to eq(DisabilityClaim::RequestDecision.jobs.first['jid'])
    end

    it 'shows a single Claim' do
      VCR.use_cassette('evss/claims/claim') do
        get '/v0/disability_claims/189625', nil, 'Authorization' => "Token token=#{session.token}"
        expect(response).to match_response_schema('disability_claim')
      end
    end

    it 'user cannot access claim of another user' do
      FactoryGirl.create(:disability_claim, id: 2, evss_id: 189_625,
                                            user_uuid: 'xyz')
      get '/v0/disability_claims/2', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:not_found)
    end

    context '5103 waiver has not been submitted yet' do
      before do
        claim.requested_decision = false
        claim.save
      end
      it 'has waiver_submitted set after requesting a decision' do
        expect(claim.requested_decision).to eq(false)
        post '/v0/disability_claims/189625/request_decision', nil, 'Authorization' => "Token token=#{session.token}"
        expect(claim.reload.requested_decision).to eq(true)
      end
    end
  end
end
