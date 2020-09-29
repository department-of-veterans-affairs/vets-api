# frozen_string_literal: true

require 'rails_helper'
require 'evss/pciu_address/military_address'

describe EVSS::PCIUAddress::MilitaryAddress do
  it 'has valid factory' do
    expect(build(:pciu_military_address)).to be_valid
  end

  it 'requires address_one' do
    expect(build(:pciu_domestic_address, address_one: '')).not_to be_valid
  end

  it 'requires zip_code and validate zip_code' do
    expect(build(:pciu_military_address, zip_code: '')).not_to be_valid
    expect(build(:pciu_domestic_address, zip_code: 'abc12')).not_to be_valid
    expect(build(:pciu_domestic_address, zip_code: '987655')).not_to be_valid
  end

  it 'has a valid military_post_office_type_code' do
    expect(build(:pciu_military_address, military_post_office_type_code: 'APO')).to be_valid
    expect(build(:pciu_military_address, military_post_office_type_code: 'NOO')).not_to be_valid
  end

  it 'has a valid military_state_code' do
    expect(build(:pciu_military_address, military_state_code: 'AE')).to be_valid
    expect(build(:pciu_military_address, military_state_code: 'ZZ')).not_to be_valid
  end

  it 'validates zip_suffix if it is present' do
    expect(build(:pciu_domestic_address, zip_suffix: '1234')).to be_valid
    expect(build(:pciu_domestic_address, zip_suffix: 'ab12')).not_to be_valid
  end
end
