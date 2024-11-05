# frozen_string_literal: true

require 'rails_helper'
require 'vba_documents/health_checker'

RSpec.describe 'VBADocument::V1::Metadata', type: :request do
  describe '#get /metadata' do
    it 'returns metadata JSON' do
      get '/services/vba_documents/metadata'
      expect(response).to have_http_status(:ok)
    end
  end
end
