# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Cemeteries Integration', type: :request do
  include SchemaMatchers

  it 'responds to GET #index' do
    VCR.use_cassette('burials/cemeteries/gets_a_list_of_cemeteries') do
      get '/v0/burials/cemeteries/'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('cemeteries')
  end
end
