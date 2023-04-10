# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Income limits endpoints', type: :request do
  describe '#get limitsByZipCode/:zip/:year/:dependents' do
    it 'returns sample data' do
      get '/income_limits/v1/limitsByZipCode/12345/2022/2'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
