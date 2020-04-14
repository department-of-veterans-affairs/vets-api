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
    let(:address_suggestion_hash) do
      {"address"=>
        {"address_line1"=>"898 Broadway W",
         "city"=>"Vancouver",
         "international_postal_code"=>"V5Z 1J8",
         "county"=>{},
         "state_province"=>{"name"=>"British Columbia", "code"=>"BC"},
         "country"=>{"name"=>"Canada", "code"=>"CAN", "fips_code"=>"CA", "iso2_code"=>"CA", "iso3_code"=>"CAN"}},
       "geocode"=>{"calc_date"=>"2020-04-10T17:29:41Z", "location_precision"=>10.0, "latitude"=>49.2635, "longitude"=>-123.13873},
       "address_meta_data"=>{"confidence_score"=>97.76, "address_type"=>"International", "validation_key"=>-1941145206
        }
      }
    end

    it 'correctly parses international addresses' do
      addr = described_class.build_from_address_suggestion(address_suggestion_hash)

      expect(addr.to_h.compact).to eq(
        {:address_line1=>"898 Broadway W",
         :address_type=>"INTERNATIONAL",
         :city=>"Vancouver",
         :country_name=>"Canada",
         :country_code_iso3=>"CAN",
         :international_postal_code=>"V5Z 1J8",
         :province=>"BC"}
      )
    end
  end
end
