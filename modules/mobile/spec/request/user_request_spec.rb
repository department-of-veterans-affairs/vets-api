# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'

RSpec.describe 'user', type: :request do
  describe 'GET /mobile/v0/user' do
    context 'with a user who has a cached iam session' do
      before { iam_sign_in }

      let(:expected_body) do
        {
          'data' => {
            'id' => '69ad43ea-6882-5673-8552-377624da64a5',
            'type' => 'user',
            'attributes' => {
              'first_name' => 'GREG',
              'middle_name' => 'A',
              'last_name' => 'ANDERSON',
              'email' => 'va.api.user+idme.008@gmail.com'
            }
          }
        }
      end

      it 'returns returns basic user info without hitting the introspect endpoint' do
        get '/mobile/v0/user', headers: { 'Authorization' => "Bearer #{access_token}" }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(expected_body)
      end
    end
  end
end
