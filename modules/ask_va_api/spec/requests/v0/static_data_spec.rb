# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AskVAApi::V0::StaticData', type: :request do
  describe 'index' do
    before do
      get '/ask_va_api/v0/static_data'
    end

    it 'response with status :ok' do
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('Emily')
    end
  end
end
