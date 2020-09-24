# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Preneeds States Integration', type: :request do
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('preneeds/states/gets_a_list_of_states') do
      get '/v0/preneeds/states/'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('preneeds/states')
  end

  it 'responds to GET #index when camel-inflected' do
    VCR.use_cassette('preneeds/states/gets_a_list_of_states') do
      get '/v0/preneeds/states/', headers: { 'X-Key-Inflection' => 'camel' }
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_camelized_response_schema('preneeds/states')
  end
end
