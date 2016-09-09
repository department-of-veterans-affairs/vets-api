# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Claims management', type: :request do
  it 'lists all Claims' do
    VCR.use_cassette('evss/claims/claims') do
      get '/v0/claims'
      expect(response).to match_response_schema('claims')
    end
  end

  it 'sets 5103 waiver when requesting a decision' do
    VCR.use_cassette('evss/claims/set_5103_waiver') do
      post '/v0/claims/189625/request_decision'
      expect(response).to be_success
      expect(response.body).to be_empty
    end
  end
end
