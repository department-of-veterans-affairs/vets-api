# frozen_string_literal: true

require 'rails_helper'
require_relative '../support/iam_session_helper'
require_relative '../support/matchers/json_schema_matcher'

RSpec.describe 'address', type: :request do
  include JsonSchemaMatchers

  before { iam_sign_in(user) }

  let(:user) { FactoryBot.build(:iam_user) }
  let(:address) { build(:va_profile_address, vet360_id: user.vet360_id) }
  let(:json_body_headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  describe 'update endpoints' do
    before(:all) do
      @original_cassette_dir = VCR.configure(&:cassette_library_dir)
      VCR.configure { |c| c.cassette_library_dir = 'modules/mobile/spec/support/vcr_cassettes' }
    end

    after(:all) { VCR.configure { |c| c.cassette_library_dir = @original_cassette_dir } }

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
          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService)
            .to receive(:seconds_elapsed_since).and_return(61)

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
          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService)
            .to receive(:seconds_elapsed_since).and_return(61)

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

  describe 'DELETE /v0/profile/addresses' do
    context 'when the method is DELETE' do
      let(:frozen_time) { Time.zone.parse('2020-02-13T20:47:45.000Z') }
      let(:address) do
        { 'address_line1' => '4041 Victoria Way',
          'address_line2' => nil,
          'address_line3' => nil,
          'address_pou' => 'CORRESPONDENCE',
          'address_type' => 'DOMESTIC',
          'city' => 'Lexington',
          'country_code_iso3' => 'USA',
          'country_code_fips' => nil,
          'county_code' => '21067',
          'county_name' => 'Fayette County',
          'created_at' => '2019-10-25T17:06:15.000Z',
          'effective_end_date' => nil,
          'effective_start_date' => '2020-02-10T17:40:15.000Z',
          'id' => 138_225,
          'international_postal_code' => nil,
          'province' => nil,
          'source_system_user' => nil,
          'state_code' => 'KY',
          'transaction_id' => '537b388e-344a-474e-be12-08d43cf35d69',
          'updated_at' => '2020-02-10T17:40:25.000Z',
          'validation_key' => nil,
          'vet360_id' => '1',
          'zip_code' => '40515',
          'zip_code_suffix' => '4655' }
      end

      it 'effective_end_date gets appended to the request body', :aggregate_failures do
        VCR.use_cassette('va_profile/contact_information/delete_address_success', VCR::MATCH_EVERYTHING) do
          # The cassette we're using includes the effectiveEndDate in the body.
          # So this test will not pass if it's missing
          delete '/mobile/v0/user/phones', params: address.to_json, headers: json_body_headers
          expect(response).to have_http_status(:ok)
          expect(response).to match_response_schema('va_profile/transaction_response')
        end
      end
    end
  end
end
