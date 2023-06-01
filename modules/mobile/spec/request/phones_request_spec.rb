# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'phones', type: :request do
  include JsonSchemaMatchers

  before { iam_sign_in(user) }

  let(:user) { FactoryBot.build(:iam_user) }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:telephone) { build(:telephone, vet360_id: user.vet360_id) }

  describe 'POST /mobile/v0/user/phones' do
    context 'with a valid phone number' do
      before do
        telephone.id = 42

        VCR.use_cassette('mobile/profile/get_phone_status_complete') do
          VCR.use_cassette('mobile/profile/get_phone_status_incomplete') do
            VCR.use_cassette('mobile/profile/post_phone_initial') do
              post('/mobile/v0/user/phones', params: telephone.to_json, headers: iam_headers(json_body_headers))
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
        expect(id).to eq('c3c6502d-f660-409c-9bc9-a7b7ce4f0bc5')
      end
    end

    context 'with missing params' do
      before do
        telephone.phone_number = ''
        post('/mobile/v0/user/phones', params: telephone.to_json, headers: iam_headers(json_body_headers))
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
            'title' => "Phone number can't be blank",
            'detail' => "phone-number - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/phone-number'
            },
            'status' => '422'
          }
        )
      end
    end
  end

  describe 'PUT /mobile/v0/user/phones' do
    context 'with a valid phone number' do
      before do
        telephone.id = 42

        VCR.use_cassette('mobile/profile/get_phone_status_complete') do
          VCR.use_cassette('mobile/profile/get_phone_status_incomplete') do
            VCR.use_cassette('mobile/profile/put_phone_initial') do
              put('/mobile/v0/user/phones', params: telephone.to_json, headers: iam_headers(json_body_headers))
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
        expect(id).to eq('c3c6502d-f660-409c-9bc9-a7b7ce4f0bc5')
      end
    end

    context 'with missing params' do
      before do
        telephone.phone_number = ''
        put('/mobile/v0/user/phones', params: telephone.to_json, headers: iam_headers(json_body_headers))
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
            'title' => "Phone number can't be blank",
            'detail' => "phone-number - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/phone-number'
            },
            'status' => '422'
          }
        )
      end
    end
  end

  describe 'DELETE /mobile/v0/user/phones' do
    context 'with a valid email' do
      before do
        telephone.id = 42

        VCR.use_cassette('mobile/profile/get_phone_status_complete') do
          VCR.use_cassette('mobile/profile/get_phone_status_incomplete') do
            VCR.use_cassette('mobile/profile/delete_phone_initial') do
              delete '/mobile/v0/user/phones',
                     params: telephone.to_json,
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
        expect(id).to eq('c3c6502d-f660-409c-9bc9-a7b7ce4f0bc5')
      end
    end

    context 'with telephone missing from params' do
      before do
        telephone.phone_number = ''
        delete('/mobile/v0/user/phones', params: telephone.to_json, headers: iam_headers(json_body_headers))
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
            'title' => "Phone number can't be blank",
            'detail' => "phone-number - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/phone-number'
            },
            'status' => '422'
          }
        )
      end
    end
  end
end
