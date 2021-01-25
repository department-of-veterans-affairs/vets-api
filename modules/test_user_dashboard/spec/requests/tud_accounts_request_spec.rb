# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Test User Dashboard', type: :request do
  context 'index' do
    it 'returns a json formatted respone' do
      get '/test_user_dashboard/tud_accounts'
      expect(response.status).to eq(200)
      expect(response.content_type).to eq('application/json; charset=utf-8')
    end
  end
end
