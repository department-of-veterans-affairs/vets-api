# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Discharge Types Integration', type: :request do
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('preneeds/discharge_types/gets_a_list_of_discharge_types') do
      get '/v0/preneeds/discharge_types/'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('preneeds/discharge_types')
  end

  it 'responds to GET #index when camel-inflected' do
    VCR.use_cassette('preneeds/discharge_types/gets_a_list_of_discharge_types') do
      get '/v0/preneeds/discharge_types/', headers: { 'X-Key-Inflection' => 'camel' }
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_camelized_response_schema('preneeds/discharge_types')
  end
end
