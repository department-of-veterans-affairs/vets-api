# frozen_string_literal: true

require 'rails_helper'
require_relative '../rails_helper'

RSpec.describe 'users', type: :request do
  describe 'GET /users' do
    context 'with a user who has an inactive iam session' do
      it 'returns a unauthorized http status code' do
        VCR.use_cassette('iam_ssoe_oauth/introspect_inactive') do
          get '/mobile/v0/user', headers: { 'Authorization' => "Bearer #{access_token}" }
        end

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a authenticated user' do
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

      context 'with a user who has an active iam session' do
        it 'returns returns basic user info' do
          VCR.use_cassette('iam_ssoe_oauth/introspect_active') do
            get '/mobile/v0/user', headers: { 'Authorization' => "Bearer #{access_token}" }
          end

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(expected_body)
        end
      end

      context 'with a user who has a cached iam session' do
        before { sign_in }

        it 'returns returns basic user info without hitting the introspect endpoint' do
          get '/mobile/v0/user', headers: { 'Authorization' => "Bearer #{access_token}" }
          puts response.body
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)).to eq(expected_body)
        end
      end
    end
  end
end
