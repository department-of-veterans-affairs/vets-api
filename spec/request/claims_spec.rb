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
      parsed_response = JSON.parse(response.body)
      expect(parsed_response['success']).to eq(true)
    end
  end
end
