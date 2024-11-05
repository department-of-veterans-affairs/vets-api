# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran::V0::Apidocs', type: :request do
  let(:openapi_version) { %w[openapi 3.0.0] }

  describe 'GET `index`' do
    it 'is successful' do
      get '/services/veteran/v0/apidocs'

      expect(response).to have_http_status(:ok)
    end

    it 'is a hash' do
      get '/services/veteran/v0/apidocs'

      expect(JSON.parse(response.body)).to be_a(Hash)
    end

    it 'has the correct openapi version' do
      get '/services/veteran/v0/apidocs'

      expect(JSON.parse(response.body).first).to eq(openapi_version)
    end
  end
end
