# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form210889', type: :request do
  let(:form_data) { VetsJsonSchema::EXAMPLES['21-0779'].to_json }

  context 'while inflection header provided' do
    it 'returns an success' do
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
end
