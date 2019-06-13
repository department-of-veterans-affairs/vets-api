# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VBA Documents Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'should return metadata JSON' do
      get '/services/vba_documents/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
