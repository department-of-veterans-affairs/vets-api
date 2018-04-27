# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Military Ranks Integration', type: :request do
  include SchemaMatchers

  let(:params) do
    { branch_of_service: 'AC', start_date: '1926-07-02', end_date: '1926-07-02' }
  end

  context 'with valid input' do
    it 'responds to GET #index' do
      VCR.use_cassette('preneeds/military_ranks/gets_a_list_of_military_ranks') do
        get '/v0/preneeds/military_ranks', params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('preneeds/military_ranks')
    end
  end

  context 'with missing parameters' do
    it 'determines if branch_of_service is missing' do
      params.delete(:branch_of_service)
      get '/v0/preneeds/military_ranks', params

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'determines if start_date is missing' do
      params.delete(:start_date)
      get '/v0/preneeds/military_ranks', params

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'determines if end_date is missing' do
      params.delete(:end_date)
      get '/v0/preneeds/military_ranks', params

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'with badly formatted fields' do
    it 'branch_of_service should only be 2 characters' do
      params[:branch_of_service] = 'A'
      get '/v0/preneeds/military_ranks', params

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'start_date should have form yyyy-mm-dd' do
      params[:start_date] = '1234'
      get '/v0/preneeds/military_ranks', params

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'end_date should have form yyyy-mm-dd' do
      params[:end_date] = '1234'
      get '/v0/preneeds/military_ranks', params

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
