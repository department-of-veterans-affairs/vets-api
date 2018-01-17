# frozen_string_literal: false

require 'rails_helper'

RSpec.describe 'institutions', type: :request do
  include SchemaMatchers

  it 'responds to GET #search' do
    VCR.use_cassette('gi_client/gets_search_results') do
      get '/v0/gi/institutions/search?name=illinois'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/institutions')
  end

  it 'responds to GET #search with bad encoding' do
    VCR.use_cassette('gi_client/gets_search_results') do
      get '/v0/gi/institutions/search?name=%ADillinois'
    end

    expect(response).to have_http_status(:bad_request)
  end

  it 'responds to GET #show' do
    VCR.use_cassette('gi_client/gets_the_institution_details') do
      get '/v0/gi/institutions/20603613'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/institution')
  end

  it 'responds to GET #autocomplete' do
    VCR.use_cassette('gi_client/gets_a_list_of_autocomplete_suggestions') do
      get '/v0/gi/institutions/autocomplete?term=university'
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/autocomplete')
  end

  it 'responds to GET #autocomplete with bad encoding' do
    VCR.use_cassette('gi_client/gets_a_list_of_autocomplete_suggestions') do
      get '/v0/gi/institutions/autocomplete?term=%ADuniversity'
    end

    expect(response).to have_http_status(:bad_request)
  end
end
