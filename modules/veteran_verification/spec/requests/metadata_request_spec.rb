# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Veteran Verification Metadata Endpoint', type: :request do
  describe '#get /metadata' do
    it 'returns veteran verification metadata JSON' do
      get '/services/veteran_verification/metadata'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
