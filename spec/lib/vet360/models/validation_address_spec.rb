# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Models::ValidationAddress do
  let(:address) { build(:vet360_validation_address, :multiple_matches) }

  describe '#address_validation_req' do
    it 'formats the address for an address validation request' do
      expect(address.address_validation_req).to eq(
        requestAddress: { 'addressLine1' => '37 1st st',
                          'city' => 'Brooklyn', :requestCountry => { countryCode: 'USA' },
                          :addressPOU => 'RESIDENCE/CHOICE', :stateProvince => { code: 'NY' },
                          :zipCode5 => '11249' }
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
          'address' => {
            'county' => { 'name' => 'Kings', 'county_fips_code' => '36047' },
            'state_province' => { 'name' => 'New York', 'code' => 'NY' },
            'country' => {
              'name' => 'United States',
              'code' => 'USA',
              'fips_code' => 'US',
              'iso2_code' => 'US',
              'iso3_code' => 'USA'
            },
            'address_line1' => '37 N 1st St',
            'city' => 'Brooklyn',
            'zip_code5' => '11249',
            'zip_code4' => '3939'
          },
          'geocode' => {
            'calc_date' => '2020-01-23T03:15:47+00:00',
            'location_precision' => 31.0, 'latitude' => 40.717029,
            'longitude' => -73.964956
          },
          'address_meta_data' => {
            'confidence_score' => 100.0, 'address_type' => 'Domestic',
            'delivery_point_validation' => 'UNDELIVERABLE',
            'validation_key' => -646_932_106
          }
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
          'address' => {
            'address_line1' => '898 Broadway W',
            'city' => 'Vancouver',
            'international_postal_code' => 'V5Z 1J8',
            'county' => {},
            'state_province' => { 'name' => 'British Columbia', 'code' => 'BC' },
            'country' => {
              'name' => 'Canada', 'code' => 'CAN',
              'fips_code' => 'CA', 'iso2_code' => 'CA', 'iso3_code' => 'CAN'
            }
          },
          'geocode' => {
            'calc_date' => '2020-04-10T17:29:41Z',
            'location_precision' => 10.0, 'latitude' => 49.2635,
            'longitude' => -123.13873
          },
          'address_meta_data' => {
            'confidence_score' => 97.76, 'address_type' => 'International',
            'validation_key' => -1_941_145_206
          }
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
