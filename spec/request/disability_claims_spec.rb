# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'disability Claims management', type: :request do
  it 'lists all Claims' do
    VCR.use_cassette('evss/claims/claims') do
      get '/v0/disability_claims'
      expect(response).to match_response_schema('disability_claims')
    end
  end

  it 'sets 5103 waiver when requesting a decision' do
    VCR.use_cassette('evss/claims/set_5103_waiver') do
      post '/v0/disability_claims/189625/request_decision'
      expect(response).to be_success
      expect(response.body).to be_empty
    end
  end

  it 'shows a single Claim' do
    VCR.use_cassette('evss/claims/claim') do
      get '/v0/disability_claims/189625'
      expect(response).to match_response_schema('disability_claim')
    end
  end
end
