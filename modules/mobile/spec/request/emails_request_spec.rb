# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'email', type: :request do
  include JsonSchemaMatchers

  before { iam_sign_in(user) }

  let(:user) { FactoryBot.build(:iam_user) }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'POST /mobile/v0/user/emails' do
    context 'with a valid email that takes two tries to complete' do
      before do
        VCR.use_cassette('mobile/profile/get_email_status_complete') do
          VCR.use_cassette('mobile/profile/get_email_status_incomplete') do
            VCR.use_cassette('mobile/profile/post_email_initial') do
              post '/mobile/v0/user/emails',
                   params: { id: 42, email_address: 'person42@example.com' }.to_json,
                   headers: iam_headers(json_body_headers)
            end
          end
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
        expect(id).to eq('d1018742-9df9-467f-88b6-f7af9e2c9894')
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

  describe 'PUT /mobile/v0/user/emails' do
    context 'with a valid email that takes two tries to complete' do
      before do
        VCR.use_cassette('mobile/profile/get_email_status_complete') do
          VCR.use_cassette('mobile/profile/get_email_status_incomplete') do
            VCR.use_cassette('mobile/profile/put_email_initial') do
              put '/mobile/v0/user/emails',
                  params: { id: 42, email_address: 'person42@example.com' }.to_json,
                  headers: iam_headers(json_body_headers)
            end
          end
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
        expect(id).to eq('d1018742-9df9-467f-88b6-f7af9e2c9894')
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

  describe 'DELETE /mobile/v0/user/emails' do
    context 'with a valid email' do
      let(:email) do
        build(:email, vet360_id: user.vet360_id, email_address: 'person103@example.com')
      end

      let(:id_in_cassette) { 42 }

      before do
        allow_any_instance_of(User).to receive(:icn).and_return('64762895576664260')
        email.id = id_in_cassette

        VCR.use_cassette('mobile/profile/get_email_status_complete') do
          VCR.use_cassette('mobile/profile/get_email_status_incomplete') do
            VCR.use_cassette('mobile/profile/delete_email_initial') do
              delete '/mobile/v0/user/emails',
                     params: { id: 42, email_address: 'person42@example.com' }.to_json,
                     headers: iam_headers(json_body_headers)
            end
          end
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
        expect(id).to eq('d1018742-9df9-467f-88b6-f7af9e2c9894')
      end
    end

    context 'with email missing from params' do
      before do
        delete '/mobile/v0/user/emails',
               params: { id: 42, email_address: '' }.to_json,
               headers: iam_headers(json_body_headers)
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
