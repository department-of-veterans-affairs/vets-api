# frozen_string_literal: true

require 'rails_helper'

describe EVSS::PCIUAddress::MilitaryAddress do
  it 'should have valid factory' do
    expect(build(:pciu_military_address)).to be_valid
  end

  it 'should require address_one' do
    expect(build(:pciu_domestic_address, address_one: '')).to_not be_valid
  end

  it 'should require zip_code and validate zip_code' do
    expect(build(:pciu_military_address, zip_code: '')).to_not be_valid
    expect(build(:pciu_domestic_address, zip_code: 'abc12')).to_not be_valid
    expect(build(:pciu_domestic_address, zip_code: '987655')).to_not be_valid
  end

  it 'should have a valid military_post_office_type_code' do
    expect(build(:pciu_military_address, military_post_office_type_code: 'APO')).to be_valid
    expect(build(:pciu_military_address, military_post_office_type_code: 'NOO')).to_not be_valid
  end

  it 'should have a valid military_state_code' do
    expect(build(:pciu_military_address, military_state_code: 'AE')).to be_valid
    expect(build(:pciu_military_address, military_state_code: 'ZZ')).to_not be_valid
  end

  it 'should validate zip_suffix if it is present' do
    expect(build(:pciu_domestic_address, zip_suffix: '1234')).to be_valid
    expect(build(:pciu_domestic_address, zip_suffix: 'ab12')).to_not be_valid
  end
end
