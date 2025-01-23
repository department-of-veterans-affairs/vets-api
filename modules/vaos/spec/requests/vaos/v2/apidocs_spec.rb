# frozen_string_literal: true

require 'rails_helper'
RSpec.describe 'VAOS::V2::Apidocs', type: :request do
  describe 'GET /vaos/v2/apidocs' do
    it 'renders the apidocs as json' do
      get '/vaos/v2/apidocs'

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).first).to eq(%w[openapi 3.0.0])
    end
  end
end
