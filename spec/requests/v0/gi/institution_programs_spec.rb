# frozen_string_literal: false

require 'rails_helper'

RSpec.describe 'V0::GI::InstitutionPrograms', type: :request do
  include SchemaMatchers

  it 'responds to GET #search with bad encoding' do
    VCR.use_cassette('gi_client/gets_institution_program_search_results') do
      get '/v0/gi/institution_programs/search?name=%ADcode'
    end

    expect(response).to be_successful
  end

  it 'responds to GET #autocomplete' do
    VCR.use_cassette('gi_client/gets_a_list_of_institution_program_autocomplete_suggestions') do
      get '/v0/gi/institution_programs/autocomplete?term=code'
    end
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('gi/autocomplete')
  end

  it 'responds to GET #autocomplete when camel-inflected' do
    VCR.use_cassette('gi_client/gets_a_list_of_institution_program_autocomplete_suggestions') do
      get '/v0/gi/institution_programs/autocomplete?term=code', headers: { 'X-Key-Inflection' => 'camel' }
    end
    expect(response).to be_successful
    expect(response.body).to be_a(String)
    expect(response).to match_camelized_response_schema('gi/autocomplete')
  end

  it 'responds to GET #autocomplete with bad encoding' do
    VCR.use_cassette('gi_client/gets_a_list_of_institution_program_autocomplete_suggestions') do
      get '/v0/gi/institution_programs/autocomplete?term=%ADcode'
    end

    expect(response).to be_successful
  end
end
