# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PCIUAddress::InternationalAddress do
  it 'has valid factory' do
    expect(build(:pciu_international_address)).to be_valid
  end

  it 'requires address_one' do
    expect(build(:pciu_international_address, address_one: '')).not_to be_valid
  end

  it 'requires city' do
    expect(build(:pciu_international_address, city: '')).not_to be_valid
  end

  it 'requires country_name' do
    expect(build(:pciu_international_address, country_name: '')).not_to be_valid
  end
end
