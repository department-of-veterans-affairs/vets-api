# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'

RSpec.describe 'Mobile::V0::User::Address', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user(icn: '123498767V234859') }

  before do
    allow(Flipper).to receive(:enabled?).with(:remove_pciu, instance_of(User)).and_return(true)
    Timecop.freeze(Time.zone.parse('2024-08-27T18:51:06.012Z'))
  end

  after do
    Timecop.return
  end

  describe 'update endpoints' do
    describe 'POST /mobile/v0/user/es' do
      let(:address) do
        address = build(:va_profile_v3_address, :mobile)
        # Some domestic addresses are coming in with province of string 'null'.
        # The controller now manually forces all domestic provinces be nil
        address.province = 'null'
        address
      end

      context 'with a valid address that takes two tries to complete' do
        before do
          VCR.use_cassette('va_profile/v2/contact_information/address_complete_status', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/address_incomplete_status', VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('va_profile/v2/contact_information/address_incomplete_status_2',
                               VCR::MATCH_EVERYTHING) do
                VCR.use_cassette('va_profile/v2/contact_information/address_incomplete_status_3',
                                 VCR::MATCH_EVERYTHING) do
                  VCR.use_cassette('va_profile/v2/contact_information/post_address_success', VCR::MATCH_EVERYTHING) do
                    post '/mobile/v0/user/addresses', params: address.to_json, headers: sis_headers(json: true)
                  end
                end
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
          expect(id).to eq('d8156f9f-06c0-4b0c-b0f7-9203b6cda078')
        end
      end

      context 'when it has not completed within the timeout window (< 60s)' do
        before do
          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService)
            .to receive(:seconds_elapsed_since).and_return(61)
          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService).to receive(:check_transaction_status!)
            .and_raise(Mobile::V0::Profile::IncompleteTransaction)

          VCR.use_cassette('va_profile/v2/contact_information/address_complete_status', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/address_incomplete_status', VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('va_profile/v2/contact_information/post_address_succes', VCR::MATCH_EVERYTHING) do
                post '/mobile/v0/user/addresses', params: address.to_json, headers: sis_headers(json: true)
              end
            end
          end
        end

        it 'returns a gateway timeout error' do
          expect(response).to have_http_status(:bad_gateway)
        end
      end

      context 'with missing address params' do
        before do
          address.address_line1 = ''

          post('/mobile/v0/user/addresses', params: address.to_json, headers: sis_headers(json: true))
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
      let(:address) { build(:va_profile_v3_address, :override, id: 577_127) }

      context 'with a valid address that takes two tries to complete' do
        before do
          Timecop.freeze(Time.zone.parse('2024-09-16T16:09:37.000Z'))
          VCR.use_cassette('va_profile/v2/contact_information/put_address_transaction_status', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/put_address_incomplete_status',
                             VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('va_profile/v2/contact_information/put_address_success', VCR::MATCH_EVERYTHING) do
                put '/mobile/v0/user/addresses', params: address.to_json, headers: sis_headers(json: true)
              end
            end
          end
        end

        after do
          Timecop.return
        end

        it 'returns a 200' do
          expect(response).to have_http_status(:ok)
        end

        it 'matches the expected schema' do
          expect(response.body).to match_json_schema('profile_update_response')
        end

        it 'includes a transaction id' do
          id = JSON.parse(response.body).dig('data', 'attributes', 'transactionId')
          expect(id).to eq('7ac85cf3-b229-4034-9897-25c0ef1411eb')
        end
      end

      context 'when it has not completed within the timeout window (< 60s)' do
        before do
          Timecop.freeze(Time.zone.parse('2024-09-16T16:09:37.000Z'))

          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService)
            .to receive(:seconds_elapsed_since).and_return(61)
          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService).to receive(:check_transaction_status!)
            .and_raise(Mobile::V0::Profile::IncompleteTransaction)

          VCR.use_cassette('va_profile/v2/contact_information/address_complete_status', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/address_incomplete_status', VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('va_profile/v2/contact_information/put_address_success', VCR::MATCH_EVERYTHING) do
                put '/mobile/v0/user/addresses', params: address.to_json, headers: sis_headers(json: true)
              end
            end
          end
        end

        after do
          Timecop.return
        end

        it 'returns a gateway timeout error' do
          expect(response).to have_http_status(:gateway_timeout)
        end
      end

      context 'with missing address params' do
        before do
          address.address_line1 = ''

          put('/mobile/v0/user/addresses', params: address.to_json, headers: sis_headers(json: true))
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
      before do
        Timecop.freeze(Time.zone.parse('2020-02-13T20:47:45.000Z'))
      end

      after do
        Timecop.return
      end

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
          'zip_code' => '40515',
          'zip_code_suffix' => '4655' }
      end

      context 'with a valid address that takes two tries to complete' do
        before do
          VCR.use_cassette('va_profile/v2/contact_information/delete_address_status_complete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/delete_address_status_incomplete',
                             VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('va_profile/v2/contact_information/delete_address_success', VCR::MATCH_EVERYTHING) do
                delete '/mobile/v0/user/addresses', params: address.to_json, headers: sis_headers(json: true)
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
          expect(id).to eq('858cfdf3-1892-4f23-b6ac-1c207c341edf')
        end
      end

      context 'when it has not completed within the timeout window (< 60s)' do
        before do
          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService)
            .to receive(:seconds_elapsed_since).and_return(61)
          allow_any_instance_of(Mobile::V0::Profile::SyncUpdateService).to receive(:check_transaction_status!)
            .and_raise(Mobile::V0::Profile::IncompleteTransaction)

          VCR.use_cassette('va_profile/v2/contact_information/delete_address_status_complete', VCR::MATCH_EVERYTHING) do
            VCR.use_cassette('va_profile/v2/contact_information/delete_address_status_incomplete',
                             VCR::MATCH_EVERYTHING) do
              VCR.use_cassette('va_profile/v2/contact_information/delete_address_success', VCR::MATCH_EVERYTHING) do
                delete '/mobile/v0/user/addresses', params: address.to_json, headers: sis_headers(json: true)
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
          address['address_line1'] = ''

          put('/mobile/v0/user/addresses', params: address.to_json, headers: sis_headers(json: true))
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
    let(:address) do
      address = build(:va_profile_v3_address)
      # Some domestic addresses are coming in with province of string 'null'.
      # The controller now manually forces all domestic provinces be nil
      address.province = 'null'
      address
    end

    context 'with an invalid address' do
      let(:invalid_address) { build(:va_profile_v3_validation_address) }

      before do
        allow(Flipper).to receive(:enabled?).with(:remove_pciu).and_return(true)
        post '/mobile/v0/user/addresses/validate',
             params: invalid_address.to_json, headers: sis_headers(json: true)
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
      let(:multiple_match_address) { build(:va_profile_v3_validation_address, :multiple_matches) }

      before do
        allow(Flipper).to receive(:enabled?).with(:remove_pciu).and_return(true)
        VCR.use_cassette(
          'va_profile/v3/address_validation/candidate_multiple_matches',
          VCR::MATCH_EVERYTHING
        ) do
          post '/mobile/v0/user/addresses/validate',
               params: multiple_match_address.to_json, headers: sis_headers(json: true)
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
            'addressPou' => 'RESIDENCE',
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
            'validationKey' => '-646932106'
          }
        )
      end
    end
  end
end
