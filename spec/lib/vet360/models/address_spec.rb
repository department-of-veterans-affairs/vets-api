# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Models::Address do
  
  describe 'validation' do
    
    context 'for any type of address' do

      let(:address) { build(:vet360_address) }

      it 'address_type is requred' do
        address.address_type = ''
        expect(address.valid?).to eq(false)
      end

      it 'address_type is requred' do
        address.address_pou = ''
        expect(address.valid?).to eq(false)
      end

      xit 'address_line1 is requred' do
        address.address_line1 = ''
        expect(address.valid?).to eq(false)
      end

      xit 'city is requred' do
        address.city = ''
        expect(address.valid?).to eq(false)
      end

      xit 'country is requred' do
        address.country = ''
        expect(address.valid?).to eq(false)
      end

      xit 'country_code_3 is requred' do
        address.country_code_iso3 = ''
        expect(address.valid?).to eq(false)
      end

    end

    xcontext 'when address_type is domestic' do
      let(:address) { build(:vet360_address, address_type: Vet360::Models::Address::DOMESTIC) }
      
      it 'state_code is required' do
        address.state_abbr = ''
        expect(address.valid?).to eq(false)
      end

      it 'state_code is required' do
        address.zip_code = ''
        expect(address.valid?).to eq(false)
      end

    end

    xcontext 'when address_type is international' do
      let(:address) { build(:vet360_address, address_type: Vet360::Models::Address::INTERNATIONAL) }
      it 'international_postal_code is required' do
        address.international_postal_code  = ''
        expect(address.valid?).to eq(false)
      end
    end

    xcontext 'when address_type is military' do
      let(:address) { build(:vet360_address, address_type: Vet360::Models::Address::MILITARY) }
      it 'international_postal_code is required' do
        address.international_postal_code  = ''
        byebug
        expect(address.valid?).to eq(false)
      end
    end

  end

end

