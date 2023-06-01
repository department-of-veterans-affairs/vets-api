# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/helpers/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'address', type: :request do
  include JsonSchemaMatchers

  before { iam_sign_in(user) }

  let(:user) { FactoryBot.build(:iam_user) }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }
  let(:address) do
    address = build(:va_profile_address, vet360_id: user.vet360_id)
    # Some domestic addresses are coming in with province of string 'null'.
    # The controller now manually forces all domestic provinces be nil
    address.province = 'null'
    address
  end

  describe 'update endpoints' do
    describe 'POST /mobile/v0/user/addresses' do
      context 'with a valid address that takes two tries to complete' do
        before do
          VCR.use_cassette('mobile/profile/get_address_status_complete') do
            VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
              VCR.use_cassette('mobile/profile/post_address_initial') do
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
          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService)
            .to receive(:seconds_elapsed_since).and_return(61)

          VCR.use_cassette('mobile/profile/get_address_status_complete') do
            VCR.use_cassette('mobile/profile/get_address_status_incomplete_2') do
              VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
                VCR.use_cassette('mobile/profile/post_address_initial') do
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
          VCR.use_cassette('mobile/profile/get_address_status_complete') do
            VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
              VCR.use_cassette('mobile/profile/put_address_initial') do
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
          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService)
            .to receive(:seconds_elapsed_since).and_return(61)

          VCR.use_cassette('mobile/profile/get_address_status_complete') do
            VCR.use_cassette('mobile/profile/get_address_status_incomplete_2') do
              VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
                VCR.use_cassette('mobile/profile/put_address_initial') do
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

    describe 'DELETE /mobile/v0/user/addresses' do
      context 'with a valid address that takes two tries to complete' do
        before do
          VCR.use_cassette('mobile/profile/get_address_status_complete') do
            VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
              VCR.use_cassette('mobile/profile/put_address_initial') do
                delete '/mobile/v0/user/addresses', params: address.to_json, headers: iam_headers(json_body_headers)
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
          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService)
            .to receive(:seconds_elapsed_since).and_return(61)

          VCR.use_cassette('mobile/profile/get_address_status_complete') do
            VCR.use_cassette('mobile/profile/get_address_status_incomplete_2') do
              VCR.use_cassette('mobile/profile/get_address_status_incomplete') do
                VCR.use_cassette('mobile/profile/put_address_initial') do
                  delete '/mobile/v0/user/addresses', params: address.to_json, headers: iam_headers(json_body_headers)
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

  describe 'POST /mobile/v0/user/addresses/validate' do
    context 'with an invalid address' do
      let(:invalid_address) { build(:va_profile_validation_address) }

      before do
        post '/mobile/v0/user/addresses/validate',
             params: invalid_address.to_json, headers: iam_headers(json_body_headers)
      end

      it 'returns a 422' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('errors')
      end

      it 'returns the error details' do
        expect(response.parsed_body).to eq(
          'errors' => [
            {
              'title' => "Address line1 can't be blank",
              'detail' => "address-line1 - can't be blank",
              'code' => '100', 'source' =>
              { 'pointer' => 'data/attributes/address-line1' },
              'status' => '422'
            },
            {
              'title' => "City can't be blank",
              'detail' => "city - can't be blank",
              'code' => '100',
              'source' => {
                'pointer' => 'data/attributes/city'
              },
              'status' => '422'
            },
            {
              'title' => "State code can't be blank",
              'detail' => "state-code - can't be blank",
              'code' => '100',
              'source' => {
                'pointer' => 'data/attributes/state-code'
              },
              'status' => '422'
            },
            {
              'title' =>
                "Zip code can't be blank",
              'detail' => "zip-code - can't be blank",
              'code' => '100',
              'source' => {
                'pointer' => 'data/attributes/zip-code'
              },
              'status' => '422'
            }
          ]
        )
      end
    end

    context 'with a found address' do
      let(:multiple_match_address) { build(:va_profile_address, :multiple_matches) }

      before do
        VCR.use_cassette(
          'va_profile/address_validation/candidate_multiple_matches',
          VCR::MATCH_EVERYTHING
        ) do
          post '/mobile/v0/user/addresses/validate',
               params: multiple_match_address.to_json, headers: iam_headers(json_body_headers)
        end
      end

      it 'returns a 200' do
        expect(response).to have_http_status(:ok)
      end

      it 'matches the expected schema' do
        expect(response.body).to match_json_schema('suggested_addresses')
      end

      it 'includes suggested correct addresses for a given address' do
        expect(response.parsed_body['data'][0]['attributes']).to eq(
          {
            'addressLine1' => '37 N 1st St',
            'addressLine2' => nil,
            'addressLine3' => nil,
            'addressPou' => 'RESIDENCE/CHOICE',
            'addressType' => 'DOMESTIC',
            'city' => 'Brooklyn',
            'countryCodeIso3' => 'USA',
            'internationalPostalCode' => nil,
            'province' => nil,
            'stateCode' => 'NY',
            'zipCode' => '11249',
            'zipCodeSuffix' => '3939'
          }
        )
      end

      it 'includes meta data for the address' do
        expect(response.parsed_body['data'][0]['meta']).to eq(
          {
            'address' => {
              'confidenceScore' => 100.0,
              'addressType' => 'Domestic',
              'deliveryPointValidation' => 'UNDELIVERABLE'
            },
            'validationKey' => -646_932_106
          }
        )
      end
    end
  end
end
