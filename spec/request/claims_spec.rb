# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Claims management', type: :request do
  it 'lists all Claims' do
    VCR.use_cassette('evss/claims/claims') do
      get '/v0/claims'
      expect(response).to match_response_schema('claims')
    end
  end
end
