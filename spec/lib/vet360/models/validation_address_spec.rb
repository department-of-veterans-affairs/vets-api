# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Models::Address do
  let(:address) { build(:vet360_validation_address, :multiple_matches) }

  describe '#address_validation_req' do
    it 'formats the address for an address validation request' do
      expect(address.address_validation_req).to eq(
        {:requestAddress=>{"addressLine1"=>"37 1st st",
          "city"=>"Brooklyn", :requestCountry=>{:countryCode=>"USA"},
          :addressPOU=>"RESIDENCE/CHOICE", :stateProvince=>{:code=>"NY"},
          :zipCode5=>"11249"}}
      )
    end
  end
end
