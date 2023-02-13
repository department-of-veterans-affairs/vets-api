# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'vaos appointment requests', type: :request do
  describe 'GET /vaos/v0/apidocs' do
    it 'renders the apidocs as json' do
      skip 'VAOS V0 routes disabled/removed'
      get '/vaos/v0/apidocs'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).first).to eq(%w[openapi 3.0.0])
    end
  end
end
