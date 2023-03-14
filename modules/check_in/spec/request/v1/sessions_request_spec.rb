# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::SessionsController', type: :request do
  describe 'GET `show`' do
    it 'returns not implemented' do
      get '/check_in/v1/sessions/1234'

      expect(response.status).to eq(501)
    end
  end

  describe 'POST `create`' do
    it 'returns not implemented' do
      post '/check_in/v1/sessions'

      expect(response.status).to eq(501)
    end
  end
end
