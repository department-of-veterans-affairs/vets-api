# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form212680', type: :request do
  let(:form_data) { VetsJsonSchema::EXAMPLES['21-2680'] }
  let(:valid_request) { { form: form_data }.to_json }

  context 'while inflection header provided' do
    it 'returns an success' do
      post(
        '/v0/form212680/download_pdf',
        params: valid_request,
        headers: {
          'Content-Type' => 'application/json',
          'X-Key-Inflection' => 'camel'
        }
      )

      expect(response).to have_http_status(:ok)
    end
  end
end
