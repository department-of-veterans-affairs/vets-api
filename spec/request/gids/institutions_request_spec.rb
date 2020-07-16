# frozen_string_literal: false

require 'rails_helper'

RSpec.describe 'institutions', type: :request do
  include SchemaMatchers

  it 'responds to GET #search' do
    VCR.use_cassette('gi_client/gets_institution_search_results') do
      get '/v0/gi/institutions/search?name=illinois'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/institutions')
  end

  it 'responds to GET #search with bad encoding' do
    VCR.use_cassette('gi_client/gets_institution_search_results') do
      get '/v0/gi/institutions/search?name=%ADillinois'
    end

    expect(response).to be_successful
  end

  it 'responds to GET #show' do
    VCR.use_cassette('gi_client/gets_the_institution_details') do
      get '/v0/gi/institutions/11902614'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/institution')
  end

  it 'responds to GET #autocomplete' do
    VCR.use_cassette('gi_client/gets_a_list_of_institution_autocomplete_suggestions') do
      get '/v0/gi/institutions/autocomplete?term=university'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/autocomplete')
  end

  it 'responds to GET #autocomplete with bad encoding' do
    VCR.use_cassette('gi_client/gets_a_list_of_institution_autocomplete_suggestions') do
      get '/v0/gi/institutions/autocomplete?term=%ADuniversity'
    end

    expect(response).to be_successful
  end

  it 'responds to GET institution #children' do
    VCR.use_cassette('gi_client/gets_the_institution_children') do
      get '/v0/gi/institutions/10086018/children'
    end

    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/institution_children')
  end
end
