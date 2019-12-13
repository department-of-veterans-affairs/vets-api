# frozen_string_literal: true

require 'rails_helper'

describe Vet360::Models::Address do
  let(:address) { build(:vet360_address) }

  describe '#zip_plus_four' do
    context 'with no zipcode' do
      it 'returns nil' do
        address.zip_code = nil
        expect(address.zip_plus_four).to eq(nil)
      end
    end

    context 'with just zipcode' do
      it 'returns just zipcode' do
        expect(address.zip_plus_four).to eq(address.zip_code)
      end
    end

    context 'with zip code suffix' do
      it 'return zip plus four' do
        address.zip_code_suffix = '1234'
        expect(address.zip_plus_four).to eq('20011-1234')
      end
    end
  end

  describe 'validation' do
    context 'for any type of address' do
      it 'address_pou is requred', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.address_pou = ''
        expect(address.valid?).to eq(false)
      end

      it 'address_line1 is requred', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.address_line1 = ''
        expect(address.valid?).to eq(false)
      end

      it 'city is requred', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.city = ''
        expect(address.valid?).to eq(false)
      end

      it 'country_name is requred', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.country_name = ''
        expect(address.valid?).to eq(false)
      end

      it 'country_name must be alphabetic', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.country_name = '42'
        expect(address.valid?).to eq(false)
      end

      it 'address_line1 < 100', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.address_line1 = 'a' * 101
        expect(address.valid?).to eq(false)
      end

      it 'zip_code_suffix must be numeric', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.zip_code_suffix = 'Hello'
        expect(address.valid?).to eq(false)
      end
    end

    context 'when address_type is domestic' do
      let(:address) { build(:vet360_address, :domestic) }

      it 'state_code is required', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.state_code = ''
        expect(address.valid?).to eq(false)
      end

      it 'zip_code is required', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.zip_code = ''
        expect(address.valid?).to eq(false)
      end

      it 'province is disallowed', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.province = 'Quebec'
        expect(address.valid?).to eq(false)
      end
    end

    context 'when address_type is international' do
      let(:address) { build(:vet360_address, :international) }

      it 'state_code is disallowed', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.state_code = 'PA'
        expect(address.valid?).to eq(false)
      end

      it 'zip_code is disallowed', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.zip_code = '19390'
        expect(address.valid?).to eq(false)
      end

      it 'zip_code_suffix is disallowed', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.zip_code_suffix = '9214'
        expect(address.valid?).to eq(false)
      end

      it 'county_name is disallowed', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.county_name = 'foo'
        expect(address.valid?).to eq(false)
      end

      it 'county_code is disallowed', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.county_code = 'bar'
        expect(address.valid?).to eq(false)
      end

      it 'international_postal_code is required', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.international_postal_code = ''
        expect(address.valid?).to eq(false)
      end

      it 'ensures international_postal_code is < 35 characters', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.international_postal_code = '123456789123456789123567891234567891234'
        expect(address.valid?).to eq(false)
      end
    end

    context 'when address_type is military' do
      let(:address) { build(:vet360_address, :military_overseas) }

      it 'state_code is required', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.state_code = ''
        expect(address.valid?).to eq(false)
      end

      it 'zip_code is required', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.zip_code = ''
        expect(address.valid?).to eq(false)
      end

      it 'province is disallowed', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.province = 'Quebec'
        expect(address.valid?).to eq(false)
      end

      it 'province_code is disallowed', :aggregate_failures do
        expect(address.valid?).to eq(true)
        address.province = 'PQ'
        expect(address.valid?).to eq(false)
      end
    end
  end
end
