# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PCIUAddress::Address do
  describe '.build_address' do
    context 'with valid domestic address attrs' do
      let(:domestic_address) { build(:pciu_domestic_address) }

      it 'builds a domestic address' do
        address = EVSS::PCIUAddress::Address.build_address(domestic_address.as_json)
        expect(address).to be_a(EVSS::PCIUAddress::DomesticAddress)
        expect(address.valid?).to be_truthy
      end
    end

    context 'with invalid domestic address attrs' do
      let(:domestic_address) { build(:pciu_domestic_address, address_one: nil, country_name: nil) }

      it 'reports as invalid and has errors' do
        address = EVSS::PCIUAddress::Address.build_address(domestic_address.as_json)
        expect(address.valid?).to be_falsey
        expect(address.errors.messages).to eq(
          address_one: ["can't be blank"]
        )
      end
    end

    context 'with valid international address attrs' do
      let(:international_address) { build(:pciu_international_address) }

      it 'builds an international address' do
        address = EVSS::PCIUAddress::Address.build_address(international_address.as_json)
        expect(address).to be_a(EVSS::PCIUAddress::InternationalAddress)
        expect(address.valid?).to be_truthy
      end
    end

    context 'with invalid international address attrs' do
      let(:international_address) { build(:pciu_international_address, country_name: nil) }

      it 'reports as invalid and has errors' do
        address = EVSS::PCIUAddress::Address.build_address(international_address.as_json)
        expect(address.valid?).to be_falsey
        expect(address.errors.messages).to eq(country_name: ["can't be blank"])
      end
    end

    context 'with valid military address attrs' do
      let(:military_address) { build(:pciu_military_address) }

      it 'builds an international address' do
        address = EVSS::PCIUAddress::Address.build_address(military_address.as_json)
        expect(address).to be_a(EVSS::PCIUAddress::MilitaryAddress)
        expect(address.valid?).to be_truthy
      end
    end

    context 'with invalid military address attrs' do
      let(:military_address) do
        build(
          :pciu_military_address, zip_code: nil, military_post_office_type_code: 'APZ', military_state_code: 'AZ'
        )
      end

      it 'reports as invalid and has errors' do
        address = EVSS::PCIUAddress::Address.build_address(military_address.as_json)
        expect(address.valid?).to be_falsey
        expect(address.errors.messages).to eq(
          zip_code: ["can't be blank", 'is invalid'],
          military_post_office_type_code: ['is not included in the list'],
          military_state_code: ['is not included in the list']
        )
      end
    end
  end
end
