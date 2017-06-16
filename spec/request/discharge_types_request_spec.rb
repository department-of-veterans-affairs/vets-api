# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Discharge Types Integration', type: :request do
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('burials/discharge_types/gets_a_list_of_discharge_types') do
      get '/v0/burials/discharge_types/'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('discharge_types')
  end
end
