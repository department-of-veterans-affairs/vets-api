# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'VeteranConfirmation::Doc::V0::Api', type: :request do
  describe '#get /docs/v0/status' do
    it 'returns Open API Spec v3 JSON' do
      get '/services/veteran_confirmation/docs/v0/api'
      expect(response).to have_http_status(:ok)
      JSON.parse(response.body)
    end
  end
end
