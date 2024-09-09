# frozen_string_literal: false

require 'rails_helper'

RSpec.describe 'V0::GI::ZipcodeRates', type: :request do
  include SchemaMatchers

  it 'responds to GET #show' do
    VCR.use_cassette('gi_client/gets_the_zipcode_rate') do
      get '/v0/gi/zipcode_rates/20001'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/zipcode_rate')
  end

  it 'responds to GET #show when camel-inflected' do
    VCR.use_cassette('gi_client/gets_the_zipcode_rate') do
      get '/v0/gi/zipcode_rates/20001', headers: { 'X-Key-Inflection' => 'camel' }
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_camelized_response_schema('gi/zipcode_rate')
  end

  it 'responds with appropriate not found' do
    VCR.use_cassette('gi_client/gets_zip_code_rate_error') do
      get '/v0/gi/zipcode_rates/splunge'
    end

    expect(response).to have_http_status(:not_found)

    json = JSON.parse(response.body)
    expect(json['errors'].length).to eq(1)
    expect(json['errors'][0]['title']).to eq('Record not found')
    expect(json['errors'][0]['detail']).to eq('Record with the specified code was not found')
  end
end
