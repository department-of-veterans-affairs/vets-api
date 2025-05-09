# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'AskVAApi::V0::AddressValidation', type: :request do
  let(:user) { build(:user) }
  let(:address) { build(:va_profile_address) }
  let(:multiple_match_addr) do
    build(:va_profile_address, :multiple_matches)
  end

  describe '#create' do
    context 'with an invalid address' do
      it 'returns an error' do
        post '/ask_va_api/v0/address_validation', params: { address: build(:va_profile_validation_address).to_h }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(
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
      it 'returns suggested addresses for a given address' do
        VCR.use_cassette(
          'va_profile/address_validation/candidate_multiple_matches',
          VCR::MATCH_EVERYTHING
        ) do
          post '/ask_va_api/v0/address_validation', params: { address: multiple_match_addr.to_h }
          expect(JSON.parse(response.body)).to eq(
            'addresses' => [
              {
                'address' => {
                  'address_line1' => '37 N 1st St',
                  'address_type' => 'DOMESTIC',
                  'city' => 'Brooklyn',
                  'country_name' => 'United States',
                  'country_code_iso3' => 'USA',
                  'county_code' => '36047',
                  'county_name' => 'Kings',
                  'state_code' => 'NY',
                  'zip_code' => '11249',
                  'zip_code_suffix' => '3939'
                },
                'address_meta_data' => {
                  'confidence_score' => 100.0,
                  'address_type' => 'Domestic',
                  'delivery_point_validation' => 'UNDELIVERABLE'
                }
              },
              {
                'address' => {
                  'address_line1' => '37 S 1st St',
                  'address_type' => 'DOMESTIC',
                  'city' => 'Brooklyn',
                  'country_name' => 'United States',
                  'country_code_iso3' => 'USA',
                  'county_code' => '36047',
                  'county_name' => 'Kings',
                  'state_code' => 'NY',
                  'zip_code' => '11249',
                  'zip_code_suffix' => '4101'
                },
                'address_meta_data' => {
                  'confidence_score' => 100.0,
                  'address_type' => 'Domestic',
                  'delivery_point_validation' => 'CONFIRMED',
                  'residential_delivery_indicator' => 'MIXED'
                }
              }
            ],
            'validation_key' => -646_932_106
          )
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end

  describe 'contact information v2' do
    let(:user) { build(:user) }
    let(:multiple_match_addr) { build(:va_profile_v3_address, :multiple_matches) }
    let(:invalid_address) { build(:va_profile_v3_validation_address).to_h }
    let(:incorrect_address_pou) { build(:va_profile_v3_address, :incorrect_address_pou) }

    before do
      allow(Flipper).to receive(:enabled?).with(:remove_pciu).and_return(true)
    end

    shared_examples 'invalid address' do
      it 'returns an error' do
        post '/ask_va_api/v0/address_validation', params: { address: invalid_address }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(JSON.parse(response.body)).to eq(
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

    shared_examples 'found address' do
      it 'returns suggested addresses for a given address' do
        VCR.use_cassette('va_profile/v3/address_validation/candidate_multiple_matches', VCR::MATCH_EVERYTHING) do
          post '/ask_va_api/v0/address_validation', params: { address: multiple_match_addr.to_h }
          expect(JSON.parse(response.body)).to eq(
            'addresses' => [
              {
                'address' => {
                  'address_line1' => '37 N 1st St',
                  'address_type' => 'DOMESTIC',
                  'city' => 'Brooklyn',
                  'country_name' => 'United States',
                  'country_code_iso3' => 'USA',
                  'county_code' => '36047',
                  'county_name' => 'Kings',
                  'state_code' => 'NY',
                  'zip_code' => '11249',
                  'zip_code_suffix' => '3939'
                },
                'address_meta_data' => {
                  'confidence_score' => 100.0,
                  'address_type' => 'Domestic',
                  'delivery_point_validation' => 'UNDELIVERABLE'
                }
              },
              {
                'address' => {
                  'address_line1' => '37 S 1st St',
                  'address_type' => 'DOMESTIC',
                  'city' => 'Brooklyn',
                  'country_name' => 'United States',
                  'country_code_iso3' => 'USA',
                  'county_code' => '36047',
                  'county_name' => 'Kings',
                  'state_code' => 'NY',
                  'zip_code' => '11249',
                  'zip_code_suffix' => '4101'
                },
                'address_meta_data' => {
                  'confidence_score' => 100.0,
                  'address_type' => 'Domestic',
                  'delivery_point_validation' => 'CONFIRMED'
                }
              }
            ],
            'override_validation_key' => -646_932_106,
            'validation_key' => -646_932_106
          )
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'request contains invalid address_pou params' do
      it 'returns a valid address' do
        VCR.use_cassette('va_profile/v3/address_validation/candidate_multiple_matches', VCR::MATCH_EVERYTHING) do
          post '/ask_va_api/v0/address_validation', params: { address: incorrect_address_pou.to_h }
          expect(JSON.parse(response.body)).to eq(
            'addresses' => [
              {
                'address' => {
                  'address_line1' => '37 N 1st St',
                  'address_type' => 'DOMESTIC',
                  'city' => 'Brooklyn',
                  'country_name' => 'United States',
                  'country_code_iso3' => 'USA',
                  'county_code' => '36047',
                  'county_name' => 'Kings',
                  'state_code' => 'NY',
                  'zip_code' => '11249',
                  'zip_code_suffix' => '3939'
                },
                'address_meta_data' => {
                  'confidence_score' => 100.0,
                  'address_type' => 'Domestic',
                  'delivery_point_validation' => 'UNDELIVERABLE'
                }
              },
              {
                'address' => {
                  'address_line1' => '37 S 1st St',
                  'address_type' => 'DOMESTIC',
                  'city' => 'Brooklyn',
                  'country_name' => 'United States',
                  'country_code_iso3' => 'USA',
                  'county_code' => '36047',
                  'county_name' => 'Kings',
                  'state_code' => 'NY',
                  'zip_code' => '11249',
                  'zip_code_suffix' => '4101'
                },
                'address_meta_data' => {
                  'confidence_score' => 100.0,
                  'address_type' => 'Domestic',
                  'delivery_point_validation' => 'CONFIRMED'
                }
              }
            ],
            'override_validation_key' => '-646932106',
            'validation_key' => '-646932106'
          )
          expect(response).to have_http_status(:ok)
        end
      end
    end
  end
end
