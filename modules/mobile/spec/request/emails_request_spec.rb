# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'email', type: :request do
  include JsonSchemaMatchers

  describe 'PUT /mobile/v0/user/emails' do
    before { iam_sign_in(user) }

    let(:user) { FactoryBot.build(:iam_user) }
    let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

    context 'with a valid email' do
      before do
        VCR.use_cassette('vet360/contact_information/put_email_success') do
          put '/mobile/v0/user/emails',
              params: { id: 42, email_address: 'person42@example.com' }.to_json,
              headers: iam_headers(json_body_headers)
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('profile_update_response')
      end

      it 'includes a transaction id' do
        id = JSON.parse(response.body).dig('data', 'attributes', 'transactionId')
        expect(id).to eq('7d1667a5-df5f-4559-be35-b36042c61187')
      end
    end

    context 'with email missing from params' do
      before do
        put('/mobile/v0/user/emails', params: { email_address: '' }.to_json, headers: iam_headers(json_body_headers))
      end

      it 'returns a 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'matches the error schema' do
        expect(response.body).to match_json_schema('errors')
      end

      it 'has a helpful error message' do
        message = response.parsed_body['errors'].first
        expect(message).to eq(
          {
            'title' => "Email address can't be blank",
            'detail' => "email-address - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/email-address'
            },
            'status' => '422'
          }
        )
      end
    end
  end
end
