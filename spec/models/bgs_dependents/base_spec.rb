# frozen_string_literal: true

require 'rails_helper'

TEST_COUNTRIES = {
  'USA' => 'USA', 'BOL' => 'Bolivia', 'BIH' => 'Bosnia-Herzegovina', 'BRN' => 'Brunei',
  'CPV' => 'Cape Verde', 'COG' => "Congo, People's Republic of",
  'COD' => 'Congo, Democratic Republic of', 'CIV' => "Cote d'Ivoire",
  'CZE' => 'Czech Republic', 'PRK' => 'North Korea', 'KOR' => 'South Korea',
  'LAO' => 'Laos', 'MKD' => 'Macedonia', 'MDA' => 'Moldavia', 'RUS' => 'Russia',
  'KNA' => 'St. Kitts', 'LCA' => 'St. Lucia', 'STP' => 'Sao-Tome/Principe',
  'SCG' => 'Serbia', 'SYR' => 'Syria', 'TZA' => 'Tanzania',
  'GBR' => 'United Kingdom', 'VEN' => 'Venezuela', 'VNM' => 'Vietnam',
  'YEM' => 'Yemen Arab Republic'
}.freeze

RSpec.describe BGSDependents::Base do
  let(:base) { described_class.new }
  let(:sample_dependent_application) do
    {
      'veteran_contact_information' => {
        'veteran_address' => {
          'country_name' => 'USA',
          'address_line1' => '8200 Doby LN',
          'city' => 'Pasadena',
          'state_code' => 'CA',
          'zip_code' => '21122'
        }
      }
    }
  end
  let(:alternative_address) do
    {
      'country_name' => 'USA',
      'address_line1' => 'Alternative LN',
      'city' => 'Stuart',
      'state_code' => 'FL',
      'zip_code' => '21122'
    }
  end

  describe '#dependent_address' do
    it 'returns the vet\'s address' do
      address = base.dependent_address(
        dependents_application: sample_dependent_application,
        lives_with_vet: true,
        alt_address: nil
      )

      expect(address).to eq(sample_dependent_application['veteran_contact_information']['veteran_address'])
    end

    it 'returns the alternative address' do
      address = base.dependent_address(
        dependents_application: sample_dependent_application,
        lives_with_vet: false,
        alt_address: alternative_address
      )

      expect(address).to eq(alternative_address)
    end

    context 'it is a foreign address' do
      TEST_COUNTRIES.each do |abbreviation, bis_value|
        it "returns #{bis_value} when it gets #{abbreviation} as the country" do
          address = sample_dependent_application['veteran_contact_information']['veteran_address']
          address['country_name'] = abbreviation
          address['international_postal_code'] = '12345'
          base.adjust_country_name_for!(address:)
          expect(address['country_name']).to eq(bis_value)
        end
      end

      it 'tests TUR when the city is Adana' do
        address = sample_dependent_application['veteran_contact_information']['veteran_address']
        address['country_name'] = 'TUR'
        address['international_postal_code'] = '12345'
        address['city'] = 'Adana'
        base.adjust_country_name_for!(address:)
        expect(address['country_name']).to eq('Turkey (Adana only)')
      end

      it 'tests TUR when the city is not Adana' do
        address = sample_dependent_application['veteran_contact_information']['veteran_address']
        address['country_name'] = 'TUR'
        address['international_postal_code'] = '12345'
        address['city'] = 'Istanbul'
        base.adjust_country_name_for!(address:)
        expect(address['country_name']).to eq('Turkey (except Adana)')
      end

      it 'tests a country outside of the hash' do
        address = sample_dependent_application['veteran_contact_information']['veteran_address']
        address['country_name'] = 'ITA'
        address['international_postal_code'] = '12345'
        base.adjust_country_name_for!(address:)
        expect(address['country_name']).to eq('Italy')
      end
    end
  end
end
