# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form210779', type: :request do
  let(:form_data) { VetsJsonSchema::EXAMPLES['21-0779'].to_json }
  let(:saved_claim) { create(:va210779) }

  context 'when inflection header provided' do
    it 'returns a success' do
      post(
        '/v0/form210779',
        params: form_data,
        headers: {
          'Content-Type' => 'application/json',
          'X-Key-Inflection' => 'camel'
        }
      )

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /v0/form210779/download_pdf' do
    it 'returns a success' do
      get("/v0/form210779/download_pdf/#{saved_claim.guid}")

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf')
    end
  end
end
