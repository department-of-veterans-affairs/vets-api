# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'email', type: :request do
  include JsonSchemaMatchers

  before { iam_sign_in(user) }

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  let(:user) { FactoryBot.build(:iam_user) }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'POST /mobile/v0/user/emails' do
    context 'with a valid email that takes two tries to complete' do
      before do
        VCR.use_cassette('profile/get_email_status_complete') do
          VCR.use_cassette('profile/get_email_status_incomplete') do
            VCR.use_cassette('profile/post_email_initial') do
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
        VCR.use_cassette('profile/get_email_status_complete') do
          VCR.use_cassette('profile/get_email_status_incomplete') do
            VCR.use_cassette('profile/put_email_initial') do
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
end
