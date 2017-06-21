# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Military Ranks Integration', type: :request do
  include SchemaMatchers

  let(:params) { { branch_of_service: 'AC', start_date: '1926-07-02' } }

  it 'responds to GET #index' do
    VCR.use_cassette('preneeds/military_ranks/gets_a_list_of_military_ranks') do
      get '/v0/preneeds/military_ranks', params
    end

    expect(response).to be_success
    expect(response.body).to be_a(String)
    expect(response).to match_response_schema('military_ranks')
  end

  context 'with missing parameters' do
    it 'validates the presence of branch_of_service' do
      params.delete(:branch_of_service)
      get '/v0/preneeds/military_ranks', params

      expect(response).to have_http_status(:bad_request)
    end

    it 'validates the presence of start_date' do
      params.delete(:start_date)
      get '/v0/preneeds/military_ranks', params

      expect(response).to have_http_status(:bad_request)
    end
  end

  context 'with invalidly formatted fields' do
    it 'validates the content of branch_of_service' do
      params[:branch_of_service] = 'A'
      get '/v0/preneeds/military_ranks', params

      expect(response).to have_http_status(:bad_request)
    end

    it 'validates the content of branch_of_service' do
      params[:start_date] = '1234'
      get '/v0/preneeds/military_ranks', params

      expect(response).to have_http_status(:bad_request)
    end
  end
end
