# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Preneeds Application Form Integration', type: :request do
  include SchemaMatchers

  let(:params) do
    { pre_need_request: JSON.parse(build(:application_form).to_json, symbolize_names: true) }
  end

  context 'with valid input' do
    it 'responds to POST #create' do
      VCR.use_cassette('preneeds/application_forms/creates_a_pre_need_application_form') do
        post '/v0/preneeds/application_forms', params
      end

      expect(response).to be_success
      expect(response.body).to be_a(String)
      expect(response).to match_response_schema('preneeds/receive_applications')
    end
  end

  context 'with invalid input' do
    it 'returns an with error' do
      params[:pre_need_request][:veteran].delete(:military_status)
      post '/v0/preneeds/application_forms', params

      error = JSON.parse(response.body)['errors'].first

      expect(error['status']).to eq('422')
      expect(error['title']).to match(/validation error/i)
      expect(error['detail']).to match(/militaryStatus/)
    end
  end
end
