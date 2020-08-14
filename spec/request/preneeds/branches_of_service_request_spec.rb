# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Branches of Service Integration', type: :request do
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('preneeds/branches_of_service/gets_a_list_of_service_branches') do
      get '/v0/preneeds/branches_of_service/'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('preneeds/branches_of_service')
  end

  it 'responds to GET #index when camel-inflected' do
    VCR.use_cassette('preneeds/branches_of_service/gets_a_list_of_service_branches') do
      get '/v0/preneeds/branches_of_service/', headers: { 'X-Key-Inflection' => 'camel' }
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_camelized_response_schema('preneeds/branches_of_service')
  end
end
