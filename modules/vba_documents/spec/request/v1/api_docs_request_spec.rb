# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::Docs::V1::ApiController, type: :request do
  describe '#get /docs/v1/api' do
    it 'returns swagger JSON' do
      get '/services/vba_documents/docs/v1/api'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
