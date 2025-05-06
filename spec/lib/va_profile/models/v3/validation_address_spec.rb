# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/v3/validation_address'

describe VAProfile::Models::V3::ValidationAddress do
  let(:address) { build(:va_profile_v3_validation_address, :multiple_matches) }

  describe '#address_validation_req' do
    it 'formats the address for an address validation request' do
      expect(address.address_validation_req).to eq(
        address: {
          'addressLine1' => '37 1st st',
          :cityName => 'Brooklyn',
          :zipCode5 => '11249',
          :country => {
            countryCodeISO3: 'USA',
            countryName: 'USA'
          },
          :state => {
            stateCode: 'NY'
          },
          :province => {},
          :addressPOU => 'RESIDENCE'
        }
      )
    end
  end

  describe '#build_from_address_suggestion' do
    subject do
      described_class.build_from_address_suggestion(address_suggestion_hash).to_h.compact
    end

    context 'with a domestic address' do
      let(:address_suggestion_hash) do
        {
          'address_line1' => '37 N 1st St',
          'city_name' => 'Brooklyn',
          'zip_code5' => '11249',
          'zip_code4' => '3939',
          'addressPOU' => 'RESIDENCE',
          'county' => { 'county_name' => 'Kings', 'county_code' => '36047' },
          'state' => { 'state_name' => 'New York', 'state_code' => 'NY' },
          'country' => {
            'country_name' => 'United States',
            'country_code_fips' => 'US',
            'country_code_iso3' => 'USA'
          },
          'geocode' => {
            'calc_date' => '2020-01-23T03:15:47+00:00',
            'location_precision' => 31.0,
            'latitude' => 40.717029,
            'longitude' => -73.964956
          },
          'confidence' => 100.0,
          'address_type' => 'Domestic',
          'delivery_point_validation' => 'UNDELIVERABLE'
        }
      end

      it 'correctly parses the addresses' do
        expect(subject).to eq(
          { address_line1: '37 N 1st St',
            address_type: 'DOMESTIC',
            city: 'Brooklyn',
            country_name: 'United States',
            country_code_iso3: 'USA',
            county_code: '36047',
            county_name: 'Kings',
            state_code: 'NY',
            zip_code: '11249',
            zip_code_suffix: '3939' }
        )
      end
    end

    context 'with an international address' do
      let(:address_suggestion_hash) do
        {
          'address_line1' => '898 Broadway W',
          'city_name' => 'Vancouver',
          'int_postal_code' => 'V5Z 1J8',
          'county' => {},
          'province' => {
            'province_name' => 'British Columbia',
            'province_code' => 'BC'
          },
          'country' => {
            'country_name' => 'Canada',
            'country_code_fips' => 'CA',
            'country_code_iso3' => 'CAN'
          },
          'geocode' => {
            'calc_date' => '2020-04-10T17:29:41Z',
            'location_precision' => 10.0, 'latitude' => 49.2635,
            'longitude' => -123.13873
          },
          'confidence' => 97.76,
          'address_type' => 'International'
        }
      end

      it 'correctly parses international addresses' do
        expect(subject).to eq(
          { address_line1: '898 Broadway W',
            address_type: 'INTERNATIONAL',
            city: 'Vancouver',
            country_name: 'Canada',
            country_code_iso3: 'CAN',
            international_postal_code: 'V5Z 1J8',
            province: 'British Columbia' }
        )
      end
    end
  end
end
