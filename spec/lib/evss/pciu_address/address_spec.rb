# frozen_string_literal: true
require 'rails_helper'

describe EVSS::PCIUAddress::Address do
  describe '.build_address' do
    context 'with a valid domestic address attrs' do
      let(:attrs) do
        {
          'type' => 'DOMESTIC',
          'address_effective_date' => '2017-08-07T19:43:59.383Z',
          'address_one' => '225 5th St',
          'address_two' => '',
          'address_three' => '',
          'city' => 'Springfield',
          'state_code' => 'OR',
          'country_name' => 'USA',
          'zip_code' => '97477',
          'zip_suffix' => ''
        }
      end

      it 'builds a domestic address' do
        address = EVSS::PCIUAddress::Address.build_address(attrs)
        expect(address).to be_a(EVSS::PCIUAddress::DomesticAddress)
        expect(address.valid?).to be_truthy
      end
    end

    context 'with invalid domestic address attrs' do
      let(:attrs) do
        {
          'type' => 'DOMESTIC',
          'address_effective_date' => '2017-08-07T19:43:59.383Z',
          'address_two' => '',
          'address_three' => '',
          'city' => 'Springfield',
          'state_code' => 'OR',
          'zip_code' => '97477',
          'zip_suffix' => ''
        }
      end

      it 'reports as invalid and has errors' do
        address = EVSS::PCIUAddress::Address.build_address(attrs)
        expect(address.valid?).to be_falsey
        expect(address.errors.messages).to eq({
                                                :address_one => ["can't be blank"],
                                                :country_name => ["can't be blank"]
                                              })
      end
    end

    context 'with a valid international address attrs' do
      let(:attrs) do
        {
          'type' => 'INTERNATIONAL',
          'address_effective_date' => '2017-08-07T19:43:59.383Z',
          'address_one' => '2 Avenue Gabriel',
          'address_two' => '',
          'address_three' => '',
          'city' => 'Paris',
          'country_name' => 'FR',
          'foreign_code' => '75008',
        }
      end

      it 'builds an international address' do
        address = EVSS::PCIUAddress::Address.build_address(attrs)
        expect(address).to be_a(EVSS::PCIUAddress::InternationalAddress)
        expect(address.valid?).to be_truthy
      end
    end

    context 'with invalid domestic address attrs' do
      let(:attrs) do
        {
          'type' => 'INTERNATIONAL',
          'address_effective_date' => '2017-08-07T19:43:59.383Z',
          'address_one' => '2 Avenue Gabriel',
          'address_two' => '',
          'address_three' => '',
          'city' => 'Paris',
        }
      end

      it 'reports as invalid and has errors' do
        address = EVSS::PCIUAddress::Address.build_address(attrs)
        expect(address.valid?).to be_falsey
        expect(address.errors.messages).to eq({:country_name=>["can't be blank"]})
      end
    end
  end
end
