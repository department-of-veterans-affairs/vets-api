# frozen_string_literal: false

require 'rails_helper'

RSpec.describe 'zipcode_rates', type: :request do
  include SchemaMatchers

  it 'responds to GET #show' do
    VCR.use_cassette('gi_client/gets_the_zipcode_rate') do
      get '/v0/gi/zipcode_rates/20001'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/zipcode_rate')
  end
end
