# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'CheckIn::V1::Sessions', type: :request do
  describe 'GET `show`' do
    it 'returns not implemented' do
      get '/check_in/v1/sessions/1234'

      expect(response).to have_http_status(:not_implemented)
    end
  end

  describe 'POST `create`' do
    it 'returns not implemented' do
      post '/check_in/v1/sessions'

      expect(response).to have_http_status(:not_implemented)
    end
  end
end
