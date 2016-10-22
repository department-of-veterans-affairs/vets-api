# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'disability Claims management', type: :request do
  let(:user) do
    user = FactoryGirl.build(:mvi_user)
    user.save
    user
  end
  let(:session) do
    session = Session.new(uuid: user.uuid)
    session.save
    session
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
      VCR.use_cassette('evss/claims/set_5103_waiver') do
        post '/v0/disability_claims/1/request_decision', nil, 'Authorization' => "Token token=#{session.token}"
        expect(response).to be_success
        expect(response.body).to be_empty
      end
    end

    it 'shows a single Claim' do
      VCR.use_cassette('evss/claims/claim') do
        get '/v0/disability_claims/1', nil, 'Authorization' => "Token token=#{session.token}"
        expect(response).to match_response_schema('disability_claim')
      end
    end

    it 'user cannot access claim of another user' do
      FactoryGirl.create(:disability_claim, id: 2, evss_id: 189_625,
                                            user_uuid: 'xyz')
      get '/v0/disability_claims/2', nil, 'Authorization' => "Token token=#{session.token}"
      expect(response).to have_http_status(:internal_server_error)
    end
  end
end
