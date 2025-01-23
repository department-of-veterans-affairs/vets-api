# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MebApi::V0::Apidocs', type: :request do
  describe 'GET /meb_api/v0/apidocs' do
    it 'renders the apidocs as json' do
      get '/meb_api/v0/apidocs'
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).first).to eq(%w[openapi 3.0.0])
    end
  end
end
