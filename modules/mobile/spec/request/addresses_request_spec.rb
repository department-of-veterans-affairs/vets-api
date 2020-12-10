# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'address', type: :request do
  include JsonSchemaMatchers

  before { iam_sign_in(user) }

  before(:all) do
    @original_cassette_dir = VCR.configure(&:cassette_library_dir)
    VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
  end

  after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

  let(:user) { FactoryBot.build(:iam_user) }
  let(:address) { build(:vet360_address, vet360_id: user.vet360_id) }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'POST /mobile/v0/user/addresses' do
    context 'with a valid address that takes two tries to complete' do
      before do
        VCR.use_cassette('profile/get_address_status_complete') do
          VCR.use_cassette('profile/get_address_status_incomplete') do
            VCR.use_cassette('profile/post_address_initial') do
              post '/mobile/v0/user/addresses', params: address.to_json, headers: iam_headers(json_body_headers)
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
        expect(id).to eq('1f450c8e-4bb2-4f5d-a5f3-0d907941625a')
      end
    end

    context 'when it has not completed within the timeout window (< 60s)' do
      before do
        allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService).to receive(:seconds_elapsed_since).and_return(61)

        VCR.use_cassette('profile/get_address_status_complete') do
          VCR.use_cassette('profile/get_address_status_incomplete_2') do
            VCR.use_cassette('profile/get_address_status_incomplete') do
              VCR.use_cassette('profile/post_address_initial') do
                post '/mobile/v0/user/addresses', params: address.to_json, headers: iam_headers(json_body_headers)
              end
            end
          end
        end
      end

      it 'returns a gateway timeout error' do
        expect(response).to have_http_status(:gateway_timeout)
      end
    end

    context 'with missing address params' do
      before do
        address.address_line1 = ''

        post('/mobile/v0/user/addresses', params: address.to_json, headers: iam_headers(json_body_headers))
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
            'title' => "Address line1 can't be blank",
            'detail' => "address-line1 - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/address-line1'
            },
            'status' => '422'
          }
        )
      end
    end
  end

  describe 'PUT /mobile/v0/user/addresses' do
    context 'with a valid address that takes two tries to complete' do
      before do
        VCR.use_cassette('profile/get_address_status_complete') do
          VCR.use_cassette('profile/get_address_status_incomplete') do
            VCR.use_cassette('profile/put_address_initial') do
              put '/mobile/v0/user/addresses', params: address.to_json, headers: iam_headers(json_body_headers)
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
        expect(id).to eq('1f450c8e-4bb2-4f5d-a5f3-0d907941625a')
      end
    end

    context 'when it has not completed within the timeout window (< 60s)' do
      before do
        allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService).to receive(:seconds_elapsed_since).and_return(61)

        VCR.use_cassette('profile/get_address_status_complete') do
          VCR.use_cassette('profile/get_address_status_incomplete_2') do
            VCR.use_cassette('profile/get_address_status_incomplete') do
              VCR.use_cassette('profile/put_address_initial') do
                put '/mobile/v0/user/addresses', params: address.to_json, headers: iam_headers(json_body_headers)
              end
            end
          end
        end
      end

      it 'returns a gateway timeout error' do
        expect(response).to have_http_status(:gateway_timeout)
      end
    end

    context 'with missing address params' do
      before do
        address.address_line1 = ''

        put('/mobile/v0/user/addresses', params: address.to_json, headers: iam_headers(json_body_headers))
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
            'title' => "Address line1 can't be blank",
            'detail' => "address-line1 - can't be blank",
            'code' => '100',
            'source' => {
              'pointer' => 'data/attributes/address-line1'
            },
            'status' => '422'
          }
        )
      end
    end
  end
end
