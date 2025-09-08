# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::V2::ConditionsController, type: :controller do
  routes { MyHealth::Engine.routes }

  let(:user) { build(:user, :mhv) }

  before do
    sign_in_as(user)
    request.env['HTTP_ACCEPT'] = 'application/json'
    request.env['CONTENT_TYPE'] = 'application/json'
  end

  describe '#index' do
    it 'returns serialized conditions successfully' do
      VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
        get :index
      end

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('data')
      expect(json_response['data']).to be_an(Array)
    end

    it 'returns empty array when no conditions found' do
      VCR.use_cassette('unified_health_data/get_conditions_no_records', match_requests_on: %i[method path]) do
        get :index
      end

      expect(response).to have_http_status(:ok)
      json_response = JSON.parse(response.body)
      expect(json_response['data']).to eq([])
    end

    it 'handles service errors gracefully' do
      allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
        .and_raise(StandardError.new('Service unavailable'))

      get :index

      expect(response).to have_http_status(:internal_server_error)
      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('errors')
    end
  end
end
